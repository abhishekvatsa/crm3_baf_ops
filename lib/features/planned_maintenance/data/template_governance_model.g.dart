// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_governance_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTemplatePackageCollection on Isar {
  IsarCollection<TemplatePackage> get templatePackages => this.collection();
}

const TemplatePackageSchema = CollectionSchema(
  name: r'TemplatePackage',
  id: 7246776624816934243,
  properties: {
    r'activeVersionFirestoreId': PropertySchema(
      id: 0,
      name: r'activeVersionFirestoreId',
      type: IsarType.string,
    ),
    r'assetNumberScope': PropertySchema(
      id: 1,
      name: r'assetNumberScope',
      type: IsarType.string,
    ),
    r'assetType': PropertySchema(
      id: 2,
      name: r'assetType',
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
    r'deviceTagRefs': PropertySchema(
      id: 11,
      name: r'deviceTagRefs',
      type: IsarType.stringList,
    ),
    r'disciplineScope': PropertySchema(
      id: 12,
      name: r'disciplineScope',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 13,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isArchived': PropertySchema(
      id: 14,
      name: r'isArchived',
      type: IsarType.bool,
    ),
    r'isAssignable': PropertySchema(
      id: 15,
      name: r'isAssignable',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 16,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isRetired': PropertySchema(
      id: 17,
      name: r'isRetired',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 18,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'latestVersionNumber': PropertySchema(
      id: 19,
      name: r'latestVersionNumber',
      type: IsarType.long,
    ),
    r'lifecycleStatus': PropertySchema(
      id: 20,
      name: r'lifecycleStatus',
      type: IsarType.string,
      enumMap: _TemplatePackagelifecycleStatusEnumValueMap,
    ),
    r'metadataJson': PropertySchema(
      id: 21,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'operationalStatePreconditions': PropertySchema(
      id: 22,
      name: r'operationalStatePreconditions',
      type: IsarType.stringList,
    ),
    r'packageCode': PropertySchema(
      id: 23,
      name: r'packageCode',
      type: IsarType.string,
    ),
    r'procedureRefs': PropertySchema(
      id: 24,
      name: r'procedureRefs',
      type: IsarType.stringList,
    ),
    r'retireReason': PropertySchema(
      id: 25,
      name: r'retireReason',
      type: IsarType.string,
    ),
    r'retiredAt': PropertySchema(
      id: 26,
      name: r'retiredAt',
      type: IsarType.dateTime,
    ),
    r'retiredByName': PropertySchema(
      id: 27,
      name: r'retiredByName',
      type: IsarType.string,
    ),
    r'retiredByUid': PropertySchema(
      id: 28,
      name: r'retiredByUid',
      type: IsarType.string,
    ),
    r'safetyClass': PropertySchema(
      id: 29,
      name: r'safetyClass',
      type: IsarType.string,
    ),
    r'safetyGatePolicyJson': PropertySchema(
      id: 30,
      name: r'safetyGatePolicyJson',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 31,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'targetRefs': PropertySchema(
      id: 32,
      name: r'targetRefs',
      type: IsarType.stringList,
    ),
    r'title': PropertySchema(
      id: 33,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 34,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 35,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 36,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 37,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _templatePackageEstimateSize,
  serialize: _templatePackageSerialize,
  deserialize: _templatePackageDeserialize,
  deserializeProp: _templatePackageDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: false,
      replace: false,
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
    r'packageCode': IndexSchema(
      id: -300968621434063,
      name: r'packageCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'packageCode',
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
    r'lifecycleStatus': IndexSchema(
      id: 6855500425116276936,
      name: r'lifecycleStatus',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lifecycleStatus',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'activeVersionFirestoreId': IndexSchema(
      id: 3461938748568725766,
      name: r'activeVersionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'activeVersionFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
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
  getId: _templatePackageGetId,
  getLinks: _templatePackageGetLinks,
  attach: _templatePackageAttach,
  version: '3.1.0+1',
);

int _templatePackageEstimateSize(
  TemplatePackage object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.activeVersionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.assetNumberScope;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.assetType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
  bytesCount += 3 + object.deviceTagRefs.length * 3;
  {
    for (var i = 0; i < object.deviceTagRefs.length; i++) {
      final value = object.deviceTagRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.disciplineScope;
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
  bytesCount += 3 + object.lifecycleStatus.name.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.operationalStatePreconditions.length * 3;
  {
    for (var i = 0; i < object.operationalStatePreconditions.length; i++) {
      final value = object.operationalStatePreconditions[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.packageCode.length * 3;
  bytesCount += 3 + object.procedureRefs.length * 3;
  {
    for (var i = 0; i < object.procedureRefs.length; i++) {
      final value = object.procedureRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.retireReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.retiredByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.retiredByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.safetyClass;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.safetyGatePolicyJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.targetRefs.length * 3;
  {
    for (var i = 0; i < object.targetRefs.length; i++) {
      final value = object.targetRefs[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
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

void _templatePackageSerialize(
  TemplatePackage object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activeVersionFirestoreId);
  writer.writeString(offsets[1], object.assetNumberScope);
  writer.writeString(offsets[2], object.assetType);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.createdByName);
  writer.writeString(offsets[5], object.createdByUid);
  writer.writeString(offsets[6], object.deleteReason);
  writer.writeDateTime(offsets[7], object.deletedAt);
  writer.writeString(offsets[8], object.deletedByName);
  writer.writeString(offsets[9], object.deletedByUid);
  writer.writeString(offsets[10], object.description);
  writer.writeStringList(offsets[11], object.deviceTagRefs);
  writer.writeString(offsets[12], object.disciplineScope);
  writer.writeString(offsets[13], object.firestoreId);
  writer.writeBool(offsets[14], object.isArchived);
  writer.writeBool(offsets[15], object.isAssignable);
  writer.writeBool(offsets[16], object.isDeleted);
  writer.writeBool(offsets[17], object.isRetired);
  writer.writeBool(offsets[18], object.isSynced);
  writer.writeLong(offsets[19], object.latestVersionNumber);
  writer.writeString(offsets[20], object.lifecycleStatus.name);
  writer.writeString(offsets[21], object.metadataJson);
  writer.writeStringList(offsets[22], object.operationalStatePreconditions);
  writer.writeString(offsets[23], object.packageCode);
  writer.writeStringList(offsets[24], object.procedureRefs);
  writer.writeString(offsets[25], object.retireReason);
  writer.writeDateTime(offsets[26], object.retiredAt);
  writer.writeString(offsets[27], object.retiredByName);
  writer.writeString(offsets[28], object.retiredByUid);
  writer.writeString(offsets[29], object.safetyClass);
  writer.writeString(offsets[30], object.safetyGatePolicyJson);
  writer.writeLong(offsets[31], object.schemaVersion);
  writer.writeStringList(offsets[32], object.targetRefs);
  writer.writeString(offsets[33], object.title);
  writer.writeDateTime(offsets[34], object.updatedAt);
  writer.writeString(offsets[35], object.updatedByName);
  writer.writeString(offsets[36], object.updatedByUid);
  writer.writeLong(offsets[37], object.version);
}

TemplatePackage _templatePackageDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TemplatePackage();
  object.activeVersionFirestoreId = reader.readStringOrNull(offsets[0]);
  object.assetNumberScope = reader.readStringOrNull(offsets[1]);
  object.assetType = reader.readStringOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.createdByName = reader.readStringOrNull(offsets[4]);
  object.createdByUid = reader.readStringOrNull(offsets[5]);
  object.deleteReason = reader.readStringOrNull(offsets[6]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[7]);
  object.deletedByName = reader.readStringOrNull(offsets[8]);
  object.deletedByUid = reader.readStringOrNull(offsets[9]);
  object.description = reader.readStringOrNull(offsets[10]);
  object.deviceTagRefs = reader.readStringList(offsets[11]) ?? [];
  object.disciplineScope = reader.readStringOrNull(offsets[12]);
  object.firestoreId = reader.readStringOrNull(offsets[13]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[16]);
  object.isSynced = reader.readBool(offsets[18]);
  object.latestVersionNumber = reader.readLong(offsets[19]);
  object.lifecycleStatus = _TemplatePackagelifecycleStatusValueEnumMap[
          reader.readStringOrNull(offsets[20])] ??
      TemplatePackageLifecycleStatus.active;
  object.metadataJson = reader.readStringOrNull(offsets[21]);
  object.operationalStatePreconditions =
      reader.readStringList(offsets[22]) ?? [];
  object.packageCode = reader.readString(offsets[23]);
  object.procedureRefs = reader.readStringList(offsets[24]) ?? [];
  object.retireReason = reader.readStringOrNull(offsets[25]);
  object.retiredAt = reader.readDateTimeOrNull(offsets[26]);
  object.retiredByName = reader.readStringOrNull(offsets[27]);
  object.retiredByUid = reader.readStringOrNull(offsets[28]);
  object.safetyClass = reader.readStringOrNull(offsets[29]);
  object.safetyGatePolicyJson = reader.readStringOrNull(offsets[30]);
  object.schemaVersion = reader.readLong(offsets[31]);
  object.targetRefs = reader.readStringList(offsets[32]) ?? [];
  object.title = reader.readString(offsets[33]);
  object.updatedAt = reader.readDateTime(offsets[34]);
  object.updatedByName = reader.readStringOrNull(offsets[35]);
  object.updatedByUid = reader.readStringOrNull(offsets[36]);
  object.version = reader.readLong(offsets[37]);
  return object;
}

P _templatePackageDeserializeProp<P>(
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
      return (reader.readStringList(offset) ?? []) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readBool(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readBool(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readLong(offset)) as P;
    case 20:
      return (_TemplatePackagelifecycleStatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          TemplatePackageLifecycleStatus.active) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readStringList(offset) ?? []) as P;
    case 23:
      return (reader.readString(offset)) as P;
    case 24:
      return (reader.readStringList(offset) ?? []) as P;
    case 25:
      return (reader.readStringOrNull(offset)) as P;
    case 26:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readStringOrNull(offset)) as P;
    case 29:
      return (reader.readStringOrNull(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readLong(offset)) as P;
    case 32:
      return (reader.readStringList(offset) ?? []) as P;
    case 33:
      return (reader.readString(offset)) as P;
    case 34:
      return (reader.readDateTime(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _TemplatePackagelifecycleStatusEnumValueMap = {
  r'active': r'active',
  r'retired': r'retired',
  r'archived': r'archived',
};
const _TemplatePackagelifecycleStatusValueEnumMap = {
  r'active': TemplatePackageLifecycleStatus.active,
  r'retired': TemplatePackageLifecycleStatus.retired,
  r'archived': TemplatePackageLifecycleStatus.archived,
};

Id _templatePackageGetId(TemplatePackage object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _templatePackageGetLinks(TemplatePackage object) {
  return [];
}

void _templatePackageAttach(
    IsarCollection<dynamic> col, Id id, TemplatePackage object) {
  object.id = id;
}

extension TemplatePackageQueryWhereSort
    on QueryBuilder<TemplatePackage, TemplatePackage, QWhere> {
  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension TemplatePackageQueryWhere
    on QueryBuilder<TemplatePackage, TemplatePackage, QWhereClause> {
  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause> idBetween(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      packageCodeEqualTo(String packageCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packageCode',
        value: [packageCode],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      packageCodeNotEqualTo(String packageCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageCode',
              lower: [],
              upper: [packageCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageCode',
              lower: [packageCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageCode',
              lower: [packageCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageCode',
              lower: [],
              upper: [packageCode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      titleEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'title',
        value: [title],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      lifecycleStatusEqualTo(TemplatePackageLifecycleStatus lifecycleStatus) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'lifecycleStatus',
        value: [lifecycleStatus],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      lifecycleStatusNotEqualTo(
          TemplatePackageLifecycleStatus lifecycleStatus) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lifecycleStatus',
              lower: [],
              upper: [lifecycleStatus],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lifecycleStatus',
              lower: [lifecycleStatus],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lifecycleStatus',
              lower: [lifecycleStatus],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'lifecycleStatus',
              lower: [],
              upper: [lifecycleStatus],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      activeVersionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'activeVersionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      activeVersionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'activeVersionFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      activeVersionFirestoreIdEqualTo(String? activeVersionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'activeVersionFirestoreId',
        value: [activeVersionFirestoreId],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      activeVersionFirestoreIdNotEqualTo(String? activeVersionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activeVersionFirestoreId',
              lower: [],
              upper: [activeVersionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activeVersionFirestoreId',
              lower: [activeVersionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activeVersionFirestoreId',
              lower: [activeVersionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'activeVersionFirestoreId',
              lower: [],
              upper: [activeVersionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterWhereClause>
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

extension TemplatePackageQueryFilter
    on QueryBuilder<TemplatePackage, TemplatePackage, QFilterCondition> {
  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'activeVersionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'activeVersionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activeVersionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'activeVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'activeVersionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeVersionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      activeVersionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'activeVersionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetNumberScope',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetNumberScope',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetNumberScope',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetNumberScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetNumberScope',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumberScope',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetNumberScopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetNumberScope',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetType',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetType',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceTagRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceTagRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTagRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceTagRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      deviceTagRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'disciplineScope',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'disciplineScope',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'disciplineScope',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'disciplineScope',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'disciplineScope',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'disciplineScope',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      disciplineScopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'disciplineScope',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      isArchivedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isArchived',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      isAssignableEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAssignable',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      isRetiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRetired',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      latestVersionNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'latestVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      latestVersionNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'latestVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      latestVersionNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'latestVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      latestVersionNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'latestVersionNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusEqualTo(
    TemplatePackageLifecycleStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusGreaterThan(
    TemplatePackageLifecycleStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusLessThan(
    TemplatePackageLifecycleStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusBetween(
    TemplatePackageLifecycleStatus lower,
    TemplatePackageLifecycleStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lifecycleStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lifecycleStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lifecycleStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      lifecycleStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lifecycleStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonEqualTo(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonGreaterThan(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonLessThan(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonBetween(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonStartsWith(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonEndsWith(
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'operationalStatePreconditions',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'operationalStatePreconditions',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      operationalStatePreconditionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'packageCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'packageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'packageCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageCode',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      packageCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'packageCode',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'procedureRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'procedureRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      procedureRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retireReason',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retireReason',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retireReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retireReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retireReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retireReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retireReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retiredByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retiredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retiredByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      retiredByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retiredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'safetyClass',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'safetyClass',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyClass',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyClass',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyClassIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'safetyGatePolicyJson',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'safetyGatePolicyJson',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyGatePolicyJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyGatePolicyJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyGatePolicyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      safetyGatePolicyJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyGatePolicyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      schemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      schemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      schemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      targetRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterFilterCondition>
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

extension TemplatePackageQueryObject
    on QueryBuilder<TemplatePackage, TemplatePackage, QFilterCondition> {}

extension TemplatePackageQueryLinks
    on QueryBuilder<TemplatePackage, TemplatePackage, QFilterCondition> {}

extension TemplatePackageQuerySortBy
    on QueryBuilder<TemplatePackage, TemplatePackage, QSortBy> {
  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByActiveVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeVersionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByActiveVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeVersionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByAssetNumberScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumberScope', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByAssetNumberScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumberScope', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDisciplineScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disciplineScope', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByDisciplineScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disciplineScope', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsAssignableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsRetiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByLatestVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latestVersionNumber', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByLatestVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latestVersionNumber', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByLifecycleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByLifecycleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByPackageCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageCode', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByPackageCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageCode', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetireReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetireReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByRetiredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySafetyGatePolicyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySafetyGatePolicyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension TemplatePackageQuerySortThenBy
    on QueryBuilder<TemplatePackage, TemplatePackage, QSortThenBy> {
  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByActiveVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeVersionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByActiveVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeVersionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByAssetNumberScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumberScope', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByAssetNumberScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumberScope', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDisciplineScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disciplineScope', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByDisciplineScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'disciplineScope', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsAssignableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsRetiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByLatestVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latestVersionNumber', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByLatestVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latestVersionNumber', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByLifecycleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByLifecycleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByPackageCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageCode', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByPackageCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageCode', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetireReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetireReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByRetiredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySafetyGatePolicyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySafetyGatePolicyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension TemplatePackageQueryWhereDistinct
    on QueryBuilder<TemplatePackage, TemplatePackage, QDistinct> {
  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByActiveVersionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeVersionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByAssetNumberScope({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumberScope',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct> distinctByAssetType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDeviceTagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceTagRefs');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByDisciplineScope({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'disciplineScope',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isArchived');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAssignable');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRetired');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByLatestVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latestVersionNumber');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByLifecycleStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lifecycleStatus',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByOperationalStatePreconditions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByPackageCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'packageCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByProcedureRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'procedureRefs');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByRetireReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retireReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredAt');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByRetiredByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByRetiredByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctBySafetyClass({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyClass', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctBySafetyGatePolicyJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyGatePolicyJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByTargetRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRefs');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackage, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension TemplatePackageQueryProperty
    on QueryBuilder<TemplatePackage, TemplatePackage, QQueryProperty> {
  QueryBuilder<TemplatePackage, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      activeVersionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeVersionFirestoreId');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      assetNumberScopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumberScope');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations> assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<TemplatePackage, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<TemplatePackage, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<TemplatePackage, List<String>, QQueryOperations>
      deviceTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceTagRefs');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      disciplineScopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'disciplineScope');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<TemplatePackage, bool, QQueryOperations> isArchivedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isArchived');
    });
  }

  QueryBuilder<TemplatePackage, bool, QQueryOperations> isAssignableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAssignable');
    });
  }

  QueryBuilder<TemplatePackage, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<TemplatePackage, bool, QQueryOperations> isRetiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRetired');
    });
  }

  QueryBuilder<TemplatePackage, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<TemplatePackage, int, QQueryOperations>
      latestVersionNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latestVersionNumber');
    });
  }

  QueryBuilder<TemplatePackage, TemplatePackageLifecycleStatus,
      QQueryOperations> lifecycleStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lifecycleStatus');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<TemplatePackage, List<String>, QQueryOperations>
      operationalStatePreconditionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<TemplatePackage, String, QQueryOperations>
      packageCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'packageCode');
    });
  }

  QueryBuilder<TemplatePackage, List<String>, QQueryOperations>
      procedureRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'procedureRefs');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      retireReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retireReason');
    });
  }

  QueryBuilder<TemplatePackage, DateTime?, QQueryOperations>
      retiredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredAt');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      retiredByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredByName');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      retiredByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredByUid');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      safetyClassProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyClass');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      safetyGatePolicyJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyGatePolicyJson');
    });
  }

  QueryBuilder<TemplatePackage, int, QQueryOperations> schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<TemplatePackage, List<String>, QQueryOperations>
      targetRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRefs');
    });
  }

  QueryBuilder<TemplatePackage, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<TemplatePackage, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<TemplatePackage, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<TemplatePackage, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTemplateVersionCollection on Isar {
  IsarCollection<TemplateVersion> get templateVersions => this.collection();
}

const TemplateVersionSchema = CollectionSchema(
  name: r'TemplateVersion',
  id: 3679262402733643249,
  properties: {
    r'changeSummary': PropertySchema(
      id: 0,
      name: r'changeSummary',
      type: IsarType.string,
    ),
    r'checklistJson': PropertySchema(
      id: 1,
      name: r'checklistJson',
      type: IsarType.string,
    ),
    r'closureCriticalModuleCount': PropertySchema(
      id: 2,
      name: r'closureCriticalModuleCount',
      type: IsarType.long,
    ),
    r'closureReviewConfirmed': PropertySchema(
      id: 3,
      name: r'closureReviewConfirmed',
      type: IsarType.bool,
    ),
    r'closureReviewConfirmedAt': PropertySchema(
      id: 4,
      name: r'closureReviewConfirmedAt',
      type: IsarType.dateTime,
    ),
    r'closureReviewConfirmedByName': PropertySchema(
      id: 5,
      name: r'closureReviewConfirmedByName',
      type: IsarType.string,
    ),
    r'closureReviewConfirmedByUid': PropertySchema(
      id: 6,
      name: r'closureReviewConfirmedByUid',
      type: IsarType.string,
    ),
    r'contentHash': PropertySchema(
      id: 7,
      name: r'contentHash',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 8,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 9,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 10,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 11,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 12,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 13,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 14,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'deviceTagRefs': PropertySchema(
      id: 15,
      name: r'deviceTagRefs',
      type: IsarType.stringList,
    ),
    r'fieldDefinitionsJson': PropertySchema(
      id: 16,
      name: r'fieldDefinitionsJson',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 17,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isArchived': PropertySchema(
      id: 18,
      name: r'isArchived',
      type: IsarType.bool,
    ),
    r'isAssignable': PropertySchema(
      id: 19,
      name: r'isAssignable',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 20,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isDraft': PropertySchema(
      id: 21,
      name: r'isDraft',
      type: IsarType.bool,
    ),
    r'isPublished': PropertySchema(
      id: 22,
      name: r'isPublished',
      type: IsarType.bool,
    ),
    r'isRetired': PropertySchema(
      id: 23,
      name: r'isRetired',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 24,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'jobTemplateSnapshotJson': PropertySchema(
      id: 25,
      name: r'jobTemplateSnapshotJson',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 26,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'minAppVersion': PropertySchema(
      id: 27,
      name: r'minAppVersion',
      type: IsarType.string,
    ),
    r'moduleSnapshotsJson': PropertySchema(
      id: 28,
      name: r'moduleSnapshotsJson',
      type: IsarType.string,
    ),
    r'operationalStatePreconditions': PropertySchema(
      id: 29,
      name: r'operationalStatePreconditions',
      type: IsarType.stringList,
    ),
    r'packageFirestoreId': PropertySchema(
      id: 30,
      name: r'packageFirestoreId',
      type: IsarType.string,
    ),
    r'procedureRefs': PropertySchema(
      id: 31,
      name: r'procedureRefs',
      type: IsarType.stringList,
    ),
    r'publishedAt': PropertySchema(
      id: 32,
      name: r'publishedAt',
      type: IsarType.dateTime,
    ),
    r'publishedByName': PropertySchema(
      id: 33,
      name: r'publishedByName',
      type: IsarType.string,
    ),
    r'publishedByUid': PropertySchema(
      id: 34,
      name: r'publishedByUid',
      type: IsarType.string,
    ),
    r'releaseNotes': PropertySchema(
      id: 35,
      name: r'releaseNotes',
      type: IsarType.string,
    ),
    r'retireReason': PropertySchema(
      id: 36,
      name: r'retireReason',
      type: IsarType.string,
    ),
    r'retiredAt': PropertySchema(
      id: 37,
      name: r'retiredAt',
      type: IsarType.dateTime,
    ),
    r'retiredByName': PropertySchema(
      id: 38,
      name: r'retiredByName',
      type: IsarType.string,
    ),
    r'retiredByUid': PropertySchema(
      id: 39,
      name: r'retiredByUid',
      type: IsarType.string,
    ),
    r'safetyClass': PropertySchema(
      id: 40,
      name: r'safetyClass',
      type: IsarType.string,
    ),
    r'safetyGatePolicyJson': PropertySchema(
      id: 41,
      name: r'safetyGatePolicyJson',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 42,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'sourceVersionFirestoreId': PropertySchema(
      id: 43,
      name: r'sourceVersionFirestoreId',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 44,
      name: r'status',
      type: IsarType.string,
      enumMap: _TemplateVersionstatusEnumValueMap,
    ),
    r'targetRefs': PropertySchema(
      id: 45,
      name: r'targetRefs',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 46,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 47,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 48,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 49,
      name: r'version',
      type: IsarType.long,
    ),
    r'versionLabel': PropertySchema(
      id: 50,
      name: r'versionLabel',
      type: IsarType.string,
    ),
    r'versionNumber': PropertySchema(
      id: 51,
      name: r'versionNumber',
      type: IsarType.long,
    )
  },
  estimateSize: _templateVersionEstimateSize,
  serialize: _templateVersionSerialize,
  deserialize: _templateVersionDeserialize,
  deserializeProp: _templateVersionDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'packageFirestoreId': IndexSchema(
      id: 3473170085998252525,
      name: r'packageFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'packageFirestoreId',
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
    r'versionNumber': IndexSchema(
      id: -8543034583656610946,
      name: r'versionNumber',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'versionNumber',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
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
  getId: _templateVersionGetId,
  getLinks: _templateVersionGetLinks,
  attach: _templateVersionAttach,
  version: '3.1.0+1',
);

int _templateVersionEstimateSize(
  TemplateVersion object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.changeSummary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.checklistJson.length * 3;
  {
    final value = object.closureReviewConfirmedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.closureReviewConfirmedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.contentHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
  bytesCount += 3 + object.deviceTagRefs.length * 3;
  {
    for (var i = 0; i < object.deviceTagRefs.length; i++) {
      final value = object.deviceTagRefs[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.fieldDefinitionsJson.length * 3;
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.jobTemplateSnapshotJson.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.minAppVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.moduleSnapshotsJson.length * 3;
  bytesCount += 3 + object.operationalStatePreconditions.length * 3;
  {
    for (var i = 0; i < object.operationalStatePreconditions.length; i++) {
      final value = object.operationalStatePreconditions[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.packageFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.procedureRefs.length * 3;
  {
    for (var i = 0; i < object.procedureRefs.length; i++) {
      final value = object.procedureRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.publishedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.publishedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.releaseNotes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.retireReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.retiredByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.retiredByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.safetyClass;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.safetyGatePolicyJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sourceVersionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.name.length * 3;
  bytesCount += 3 + object.targetRefs.length * 3;
  {
    for (var i = 0; i < object.targetRefs.length; i++) {
      final value = object.targetRefs[i];
      bytesCount += value.length * 3;
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
  {
    final value = object.versionLabel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _templateVersionSerialize(
  TemplateVersion object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.changeSummary);
  writer.writeString(offsets[1], object.checklistJson);
  writer.writeLong(offsets[2], object.closureCriticalModuleCount);
  writer.writeBool(offsets[3], object.closureReviewConfirmed);
  writer.writeDateTime(offsets[4], object.closureReviewConfirmedAt);
  writer.writeString(offsets[5], object.closureReviewConfirmedByName);
  writer.writeString(offsets[6], object.closureReviewConfirmedByUid);
  writer.writeString(offsets[7], object.contentHash);
  writer.writeDateTime(offsets[8], object.createdAt);
  writer.writeString(offsets[9], object.createdByName);
  writer.writeString(offsets[10], object.createdByUid);
  writer.writeString(offsets[11], object.deleteReason);
  writer.writeDateTime(offsets[12], object.deletedAt);
  writer.writeString(offsets[13], object.deletedByName);
  writer.writeString(offsets[14], object.deletedByUid);
  writer.writeStringList(offsets[15], object.deviceTagRefs);
  writer.writeString(offsets[16], object.fieldDefinitionsJson);
  writer.writeString(offsets[17], object.firestoreId);
  writer.writeBool(offsets[18], object.isArchived);
  writer.writeBool(offsets[19], object.isAssignable);
  writer.writeBool(offsets[20], object.isDeleted);
  writer.writeBool(offsets[21], object.isDraft);
  writer.writeBool(offsets[22], object.isPublished);
  writer.writeBool(offsets[23], object.isRetired);
  writer.writeBool(offsets[24], object.isSynced);
  writer.writeString(offsets[25], object.jobTemplateSnapshotJson);
  writer.writeString(offsets[26], object.metadataJson);
  writer.writeString(offsets[27], object.minAppVersion);
  writer.writeString(offsets[28], object.moduleSnapshotsJson);
  writer.writeStringList(offsets[29], object.operationalStatePreconditions);
  writer.writeString(offsets[30], object.packageFirestoreId);
  writer.writeStringList(offsets[31], object.procedureRefs);
  writer.writeDateTime(offsets[32], object.publishedAt);
  writer.writeString(offsets[33], object.publishedByName);
  writer.writeString(offsets[34], object.publishedByUid);
  writer.writeString(offsets[35], object.releaseNotes);
  writer.writeString(offsets[36], object.retireReason);
  writer.writeDateTime(offsets[37], object.retiredAt);
  writer.writeString(offsets[38], object.retiredByName);
  writer.writeString(offsets[39], object.retiredByUid);
  writer.writeString(offsets[40], object.safetyClass);
  writer.writeString(offsets[41], object.safetyGatePolicyJson);
  writer.writeLong(offsets[42], object.schemaVersion);
  writer.writeString(offsets[43], object.sourceVersionFirestoreId);
  writer.writeString(offsets[44], object.status.name);
  writer.writeStringList(offsets[45], object.targetRefs);
  writer.writeDateTime(offsets[46], object.updatedAt);
  writer.writeString(offsets[47], object.updatedByName);
  writer.writeString(offsets[48], object.updatedByUid);
  writer.writeLong(offsets[49], object.version);
  writer.writeString(offsets[50], object.versionLabel);
  writer.writeLong(offsets[51], object.versionNumber);
}

TemplateVersion _templateVersionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TemplateVersion();
  object.changeSummary = reader.readStringOrNull(offsets[0]);
  object.checklistJson = reader.readString(offsets[1]);
  object.closureCriticalModuleCount = reader.readLong(offsets[2]);
  object.closureReviewConfirmed = reader.readBool(offsets[3]);
  object.closureReviewConfirmedAt = reader.readDateTimeOrNull(offsets[4]);
  object.closureReviewConfirmedByName = reader.readStringOrNull(offsets[5]);
  object.closureReviewConfirmedByUid = reader.readStringOrNull(offsets[6]);
  object.contentHash = reader.readStringOrNull(offsets[7]);
  object.createdAt = reader.readDateTime(offsets[8]);
  object.createdByName = reader.readStringOrNull(offsets[9]);
  object.createdByUid = reader.readStringOrNull(offsets[10]);
  object.deleteReason = reader.readStringOrNull(offsets[11]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[12]);
  object.deletedByName = reader.readStringOrNull(offsets[13]);
  object.deletedByUid = reader.readStringOrNull(offsets[14]);
  object.deviceTagRefs = reader.readStringList(offsets[15]) ?? [];
  object.fieldDefinitionsJson = reader.readString(offsets[16]);
  object.firestoreId = reader.readStringOrNull(offsets[17]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[20]);
  object.isSynced = reader.readBool(offsets[24]);
  object.jobTemplateSnapshotJson = reader.readString(offsets[25]);
  object.metadataJson = reader.readStringOrNull(offsets[26]);
  object.minAppVersion = reader.readStringOrNull(offsets[27]);
  object.moduleSnapshotsJson = reader.readString(offsets[28]);
  object.operationalStatePreconditions =
      reader.readStringList(offsets[29]) ?? [];
  object.packageFirestoreId = reader.readStringOrNull(offsets[30]);
  object.procedureRefs = reader.readStringList(offsets[31]) ?? [];
  object.publishedAt = reader.readDateTimeOrNull(offsets[32]);
  object.publishedByName = reader.readStringOrNull(offsets[33]);
  object.publishedByUid = reader.readStringOrNull(offsets[34]);
  object.releaseNotes = reader.readStringOrNull(offsets[35]);
  object.retireReason = reader.readStringOrNull(offsets[36]);
  object.retiredAt = reader.readDateTimeOrNull(offsets[37]);
  object.retiredByName = reader.readStringOrNull(offsets[38]);
  object.retiredByUid = reader.readStringOrNull(offsets[39]);
  object.safetyClass = reader.readStringOrNull(offsets[40]);
  object.safetyGatePolicyJson = reader.readStringOrNull(offsets[41]);
  object.schemaVersion = reader.readLong(offsets[42]);
  object.sourceVersionFirestoreId = reader.readStringOrNull(offsets[43]);
  object.status = _TemplateVersionstatusValueEnumMap[
          reader.readStringOrNull(offsets[44])] ??
      TemplateVersionStatus.draft;
  object.targetRefs = reader.readStringList(offsets[45]) ?? [];
  object.updatedAt = reader.readDateTime(offsets[46]);
  object.updatedByName = reader.readStringOrNull(offsets[47]);
  object.updatedByUid = reader.readStringOrNull(offsets[48]);
  object.version = reader.readLong(offsets[49]);
  object.versionLabel = reader.readStringOrNull(offsets[50]);
  object.versionNumber = reader.readLong(offsets[51]);
  return object;
}

P _templateVersionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
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
    case 15:
      return (reader.readStringList(offset) ?? []) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readBool(offset)) as P;
    case 20:
      return (reader.readBool(offset)) as P;
    case 21:
      return (reader.readBool(offset)) as P;
    case 22:
      return (reader.readBool(offset)) as P;
    case 23:
      return (reader.readBool(offset)) as P;
    case 24:
      return (reader.readBool(offset)) as P;
    case 25:
      return (reader.readString(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readString(offset)) as P;
    case 29:
      return (reader.readStringList(offset) ?? []) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readStringList(offset) ?? []) as P;
    case 32:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readStringOrNull(offset)) as P;
    case 40:
      return (reader.readStringOrNull(offset)) as P;
    case 41:
      return (reader.readStringOrNull(offset)) as P;
    case 42:
      return (reader.readLong(offset)) as P;
    case 43:
      return (reader.readStringOrNull(offset)) as P;
    case 44:
      return (_TemplateVersionstatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          TemplateVersionStatus.draft) as P;
    case 45:
      return (reader.readStringList(offset) ?? []) as P;
    case 46:
      return (reader.readDateTime(offset)) as P;
    case 47:
      return (reader.readStringOrNull(offset)) as P;
    case 48:
      return (reader.readStringOrNull(offset)) as P;
    case 49:
      return (reader.readLong(offset)) as P;
    case 50:
      return (reader.readStringOrNull(offset)) as P;
    case 51:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _TemplateVersionstatusEnumValueMap = {
  r'draft': r'draft',
  r'published': r'published',
  r'retired': r'retired',
  r'archived': r'archived',
};
const _TemplateVersionstatusValueEnumMap = {
  r'draft': TemplateVersionStatus.draft,
  r'published': TemplateVersionStatus.published,
  r'retired': TemplateVersionStatus.retired,
  r'archived': TemplateVersionStatus.archived,
};

Id _templateVersionGetId(TemplateVersion object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _templateVersionGetLinks(TemplateVersion object) {
  return [];
}

void _templateVersionAttach(
    IsarCollection<dynamic> col, Id id, TemplateVersion object) {
  object.id = id;
}

extension TemplateVersionQueryWhereSort
    on QueryBuilder<TemplateVersion, TemplateVersion, QWhere> {
  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhere>
      anyVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'versionNumber'),
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension TemplateVersionQueryWhere
    on QueryBuilder<TemplateVersion, TemplateVersion, QWhereClause> {
  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause> idBetween(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      packageFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packageFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      packageFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'packageFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      packageFirestoreIdEqualTo(String? packageFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packageFirestoreId',
        value: [packageFirestoreId],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      packageFirestoreIdNotEqualTo(String? packageFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [],
              upper: [packageFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [packageFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [packageFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [],
              upper: [packageFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      versionNumberEqualTo(int versionNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'versionNumber',
        value: [versionNumber],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      versionNumberNotEqualTo(int versionNumber) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionNumber',
              lower: [],
              upper: [versionNumber],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionNumber',
              lower: [versionNumber],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionNumber',
              lower: [versionNumber],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionNumber',
              lower: [],
              upper: [versionNumber],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      versionNumberGreaterThan(
    int versionNumber, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'versionNumber',
        lower: [versionNumber],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      versionNumberLessThan(
    int versionNumber, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'versionNumber',
        lower: [],
        upper: [versionNumber],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      versionNumberBetween(
    int lowerVersionNumber,
    int upperVersionNumber, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'versionNumber',
        lower: [lowerVersionNumber],
        includeLower: includeLower,
        upper: [upperVersionNumber],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      statusEqualTo(TemplateVersionStatus status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      statusNotEqualTo(TemplateVersionStatus status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [status],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'status',
              lower: [],
              upper: [status],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [createdAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'createdAt',
              lower: [],
              upper: [createdAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      createdAtGreaterThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [createdAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      createdAtLessThan(
    DateTime createdAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [],
        upper: [createdAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'createdAt',
        lower: [lowerCreatedAt],
        includeLower: includeLower,
        upper: [upperCreatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterWhereClause>
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

extension TemplateVersionQueryFilter
    on QueryBuilder<TemplateVersion, TemplateVersion, QFilterCondition> {
  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'changeSummary',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'changeSummary',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'changeSummary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'changeSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      changeSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checklistJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'checklistJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'checklistJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checklistJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      checklistJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'checklistJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureCriticalModuleCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureCriticalModuleCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureCriticalModuleCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closureCriticalModuleCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureCriticalModuleCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closureCriticalModuleCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureCriticalModuleCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closureCriticalModuleCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmed',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closureReviewConfirmedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closureReviewConfirmedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closureReviewConfirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closureReviewConfirmedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closureReviewConfirmedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closureReviewConfirmedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closureReviewConfirmedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closureReviewConfirmedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closureReviewConfirmedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closureReviewConfirmedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closureReviewConfirmedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closureReviewConfirmedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closureReviewConfirmedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closureReviewConfirmedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closureReviewConfirmedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closureReviewConfirmedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closureReviewConfirmedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      closureReviewConfirmedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closureReviewConfirmedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'contentHash',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'contentHash',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      contentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceTagRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceTagRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceTagRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTagRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceTagRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      deviceTagRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTagRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fieldDefinitionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fieldDefinitionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fieldDefinitionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      fieldDefinitionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fieldDefinitionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isArchivedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isArchived',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isAssignableEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAssignable',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isDraftEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDraft',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isPublishedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPublished',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isRetiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRetired',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobTemplateSnapshotJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'jobTemplateSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'jobTemplateSnapshotJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobTemplateSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      jobTemplateSnapshotJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobTemplateSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonEqualTo(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonGreaterThan(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonLessThan(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonBetween(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonStartsWith(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonEndsWith(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'minAppVersion',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'minAppVersion',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minAppVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'minAppVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'minAppVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minAppVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      minAppVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'minAppVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleSnapshotsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleSnapshotsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleSnapshotsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleSnapshotsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      moduleSnapshotsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleSnapshotsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'operationalStatePreconditions',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'operationalStatePreconditions',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'operationalStatePreconditions',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      operationalStatePreconditionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'operationalStatePreconditions',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'packageFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'packageFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'packageFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'packageFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      packageFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'packageFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'procedureRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'procedureRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      procedureRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'procedureRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'publishedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'publishedAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publishedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publishedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publishedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'publishedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'publishedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publishedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'publishedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'publishedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'publishedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'publishedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'publishedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publishedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'publishedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'publishedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      publishedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'publishedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'releaseNotes',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'releaseNotes',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'releaseNotes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'releaseNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'releaseNotes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'releaseNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      releaseNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'releaseNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retireReason',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retireReason',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retireReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retireReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retireReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retireReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retireReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retireReason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retiredByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retiredByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retiredByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'retiredByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'retiredByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      retiredByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'retiredByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'safetyClass',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'safetyClass',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyClass',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyClass',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyClassIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'safetyGatePolicyJson',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'safetyGatePolicyJson',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyGatePolicyJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyGatePolicyJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyGatePolicyJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyGatePolicyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      safetyGatePolicyJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyGatePolicyJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      schemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      schemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      schemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sourceVersionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sourceVersionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceVersionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceVersionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceVersionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceVersionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      sourceVersionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceVersionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusEqualTo(
    TemplateVersionStatus value, {
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusGreaterThan(
    TemplateVersionStatus value, {
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusLessThan(
    TemplateVersionStatus value, {
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusBetween(
    TemplateVersionStatus lower,
    TemplateVersionStatus upper, {
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusStartsWith(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusEndsWith(
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      targetRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'targetRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
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

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'versionLabel',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'versionLabel',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'versionLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'versionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'versionLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'versionLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'versionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'versionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterFilterCondition>
      versionNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'versionNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TemplateVersionQueryObject
    on QueryBuilder<TemplateVersion, TemplateVersion, QFilterCondition> {}

extension TemplateVersionQueryLinks
    on QueryBuilder<TemplateVersion, TemplateVersion, QFilterCondition> {}

extension TemplateVersionQuerySortBy
    on QueryBuilder<TemplateVersion, TemplateVersion, QSortBy> {
  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByChecklistJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByChecklistJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureCriticalModuleCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureCriticalModuleCount', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureCriticalModuleCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureCriticalModuleCount', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmed', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmed', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByClosureReviewConfirmedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByFieldDefinitionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByFieldDefinitionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsAssignableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> sortByIsDraft() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDraft', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsDraftDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDraft', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublished', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsPublishedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublished', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsRetiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByJobTemplateSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobTemplateSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByJobTemplateSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobTemplateSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByMinAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minAppVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByMinAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minAppVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByModuleSnapshotsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotsJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByModuleSnapshotsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotsJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPackageFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPackageFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByPublishedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByReleaseNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'releaseNotes', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByReleaseNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'releaseNotes', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetireReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetireReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByRetiredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySafetyGatePolicyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySafetyGatePolicyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySourceVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceVersionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortBySourceVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceVersionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByVersionLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLabel', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByVersionLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLabel', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionNumber', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      sortByVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionNumber', Sort.desc);
    });
  }
}

extension TemplateVersionQuerySortThenBy
    on QueryBuilder<TemplateVersion, TemplateVersion, QSortThenBy> {
  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByChecklistJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByChecklistJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checklistJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureCriticalModuleCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureCriticalModuleCount', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureCriticalModuleCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureCriticalModuleCount', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmed', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmed', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByClosureReviewConfirmedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closureReviewConfirmedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentHash', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByFieldDefinitionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByFieldDefinitionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsArchivedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isArchived', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsAssignableDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAssignable', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> thenByIsDraft() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDraft', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsDraftDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDraft', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublished', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsPublishedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublished', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsRetiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRetired', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByJobTemplateSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobTemplateSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByJobTemplateSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobTemplateSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByMinAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minAppVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByMinAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minAppVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByModuleSnapshotsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotsJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByModuleSnapshotsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotsJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPackageFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPackageFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByPublishedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByReleaseNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'releaseNotes', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByReleaseNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'releaseNotes', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetireReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetireReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retireReason', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByRetiredByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySafetyGatePolicyJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySafetyGatePolicyJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyGatePolicyJson', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySourceVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceVersionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenBySourceVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceVersionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByVersionLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLabel', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByVersionLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionLabel', Sort.desc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionNumber', Sort.asc);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QAfterSortBy>
      thenByVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionNumber', Sort.desc);
    });
  }
}

extension TemplateVersionQueryWhereDistinct
    on QueryBuilder<TemplateVersion, TemplateVersion, QDistinct> {
  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByChangeSummary({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'changeSummary',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByChecklistJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checklistJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByClosureCriticalModuleCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closureCriticalModuleCount');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByClosureReviewConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closureReviewConfirmed');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByClosureReviewConfirmedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closureReviewConfirmedAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByClosureReviewConfirmedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closureReviewConfirmedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByClosureReviewConfirmedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closureReviewConfirmedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByContentHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByDeviceTagRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceTagRefs');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByFieldDefinitionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fieldDefinitionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsArchived() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isArchived');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsAssignable() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAssignable');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsDraft() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDraft');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPublished');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsRetired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRetired');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByJobTemplateSnapshotJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobTemplateSnapshotJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByMinAppVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minAppVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByModuleSnapshotsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleSnapshotsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByOperationalStatePreconditions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByPackageFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'packageFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByProcedureRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'procedureRefs');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publishedAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByPublishedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publishedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByPublishedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publishedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByReleaseNotes({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'releaseNotes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByRetireReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retireReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByRetiredByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByRetiredByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctBySafetyClass({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyClass', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctBySafetyGatePolicyJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyGatePolicyJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctBySourceVersionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceVersionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByTargetRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRefs');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByVersionLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersion, QDistinct>
      distinctByVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionNumber');
    });
  }
}

extension TemplateVersionQueryProperty
    on QueryBuilder<TemplateVersion, TemplateVersion, QQueryProperty> {
  QueryBuilder<TemplateVersion, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      changeSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'changeSummary');
    });
  }

  QueryBuilder<TemplateVersion, String, QQueryOperations>
      checklistJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checklistJson');
    });
  }

  QueryBuilder<TemplateVersion, int, QQueryOperations>
      closureCriticalModuleCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closureCriticalModuleCount');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations>
      closureReviewConfirmedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closureReviewConfirmed');
    });
  }

  QueryBuilder<TemplateVersion, DateTime?, QQueryOperations>
      closureReviewConfirmedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closureReviewConfirmedAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      closureReviewConfirmedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closureReviewConfirmedByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      closureReviewConfirmedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closureReviewConfirmedByUid');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      contentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentHash');
    });
  }

  QueryBuilder<TemplateVersion, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<TemplateVersion, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<TemplateVersion, List<String>, QQueryOperations>
      deviceTagRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceTagRefs');
    });
  }

  QueryBuilder<TemplateVersion, String, QQueryOperations>
      fieldDefinitionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fieldDefinitionsJson');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isArchivedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isArchived');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isAssignableProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAssignable');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isDraftProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDraft');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isPublishedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPublished');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isRetiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRetired');
    });
  }

  QueryBuilder<TemplateVersion, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<TemplateVersion, String, QQueryOperations>
      jobTemplateSnapshotJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobTemplateSnapshotJson');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      minAppVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minAppVersion');
    });
  }

  QueryBuilder<TemplateVersion, String, QQueryOperations>
      moduleSnapshotsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleSnapshotsJson');
    });
  }

  QueryBuilder<TemplateVersion, List<String>, QQueryOperations>
      operationalStatePreconditionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      packageFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'packageFirestoreId');
    });
  }

  QueryBuilder<TemplateVersion, List<String>, QQueryOperations>
      procedureRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'procedureRefs');
    });
  }

  QueryBuilder<TemplateVersion, DateTime?, QQueryOperations>
      publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publishedAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      publishedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publishedByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      publishedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publishedByUid');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      releaseNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'releaseNotes');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      retireReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retireReason');
    });
  }

  QueryBuilder<TemplateVersion, DateTime?, QQueryOperations>
      retiredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      retiredByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      retiredByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredByUid');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      safetyClassProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyClass');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      safetyGatePolicyJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyGatePolicyJson');
    });
  }

  QueryBuilder<TemplateVersion, int, QQueryOperations> schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      sourceVersionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceVersionFirestoreId');
    });
  }

  QueryBuilder<TemplateVersion, TemplateVersionStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<TemplateVersion, List<String>, QQueryOperations>
      targetRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRefs');
    });
  }

  QueryBuilder<TemplateVersion, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<TemplateVersion, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<TemplateVersion, String?, QQueryOperations>
      versionLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionLabel');
    });
  }

  QueryBuilder<TemplateVersion, int, QQueryOperations> versionNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionNumber');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTemplatePublishAuditCollection on Isar {
  IsarCollection<TemplatePublishAudit> get templatePublishAudits =>
      this.collection();
}

const TemplatePublishAuditSchema = CollectionSchema(
  name: r'TemplatePublishAudit',
  id: -236492924270429194,
  properties: {
    r'action': PropertySchema(
      id: 0,
      name: r'action',
      type: IsarType.string,
      enumMap: _TemplatePublishAuditactionEnumValueMap,
    ),
    r'afterHash': PropertySchema(
      id: 1,
      name: r'afterHash',
      type: IsarType.string,
    ),
    r'beforeHash': PropertySchema(
      id: 2,
      name: r'beforeHash',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 3,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 4,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 5,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'metadataJson': PropertySchema(
      id: 6,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'packageFirestoreId': PropertySchema(
      id: 7,
      name: r'packageFirestoreId',
      type: IsarType.string,
    ),
    r'payloadSnapshotJson': PropertySchema(
      id: 8,
      name: r'payloadSnapshotJson',
      type: IsarType.string,
    ),
    r'performedAt': PropertySchema(
      id: 9,
      name: r'performedAt',
      type: IsarType.dateTime,
    ),
    r'performedByName': PropertySchema(
      id: 10,
      name: r'performedByName',
      type: IsarType.string,
    ),
    r'performedByUid': PropertySchema(
      id: 11,
      name: r'performedByUid',
      type: IsarType.string,
    ),
    r'reason': PropertySchema(
      id: 12,
      name: r'reason',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 13,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 14,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 15,
      name: r'version',
      type: IsarType.long,
    ),
    r'versionFirestoreId': PropertySchema(
      id: 16,
      name: r'versionFirestoreId',
      type: IsarType.string,
    )
  },
  estimateSize: _templatePublishAuditEstimateSize,
  serialize: _templatePublishAuditSerialize,
  deserialize: _templatePublishAuditDeserialize,
  deserializeProp: _templatePublishAuditDeserializeProp,
  idName: r'id',
  indexes: {
    r'firestoreId': IndexSchema(
      id: 1863077355534729001,
      name: r'firestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'firestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'packageFirestoreId': IndexSchema(
      id: 3473170085998252525,
      name: r'packageFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'packageFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'versionFirestoreId': IndexSchema(
      id: -5750171890140352656,
      name: r'versionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'versionFirestoreId',
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
    r'action': IndexSchema(
      id: -2948318935682215514,
      name: r'action',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'action',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'performedAt': IndexSchema(
      id: 261083574192956769,
      name: r'performedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'performedAt',
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
  getId: _templatePublishAuditGetId,
  getLinks: _templatePublishAuditGetLinks,
  attach: _templatePublishAuditAttach,
  version: '3.1.0+1',
);

int _templatePublishAuditEstimateSize(
  TemplatePublishAudit object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.action.name.length * 3;
  {
    final value = object.afterHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.beforeHash;
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
  {
    final value = object.packageFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.payloadSnapshotJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.performedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.performedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.versionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _templatePublishAuditSerialize(
  TemplatePublishAudit object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.action.name);
  writer.writeString(offsets[1], object.afterHash);
  writer.writeString(offsets[2], object.beforeHash);
  writer.writeString(offsets[3], object.firestoreId);
  writer.writeBool(offsets[4], object.isDeleted);
  writer.writeBool(offsets[5], object.isSynced);
  writer.writeString(offsets[6], object.metadataJson);
  writer.writeString(offsets[7], object.packageFirestoreId);
  writer.writeString(offsets[8], object.payloadSnapshotJson);
  writer.writeDateTime(offsets[9], object.performedAt);
  writer.writeString(offsets[10], object.performedByName);
  writer.writeString(offsets[11], object.performedByUid);
  writer.writeString(offsets[12], object.reason);
  writer.writeLong(offsets[13], object.schemaVersion);
  writer.writeDateTime(offsets[14], object.updatedAt);
  writer.writeLong(offsets[15], object.version);
  writer.writeString(offsets[16], object.versionFirestoreId);
}

TemplatePublishAudit _templatePublishAuditDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TemplatePublishAudit();
  object.action = _TemplatePublishAuditactionValueEnumMap[
          reader.readStringOrNull(offsets[0])] ??
      TemplatePublishAuditAction.created;
  object.afterHash = reader.readStringOrNull(offsets[1]);
  object.beforeHash = reader.readStringOrNull(offsets[2]);
  object.firestoreId = reader.readStringOrNull(offsets[3]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[4]);
  object.isSynced = reader.readBool(offsets[5]);
  object.metadataJson = reader.readStringOrNull(offsets[6]);
  object.packageFirestoreId = reader.readStringOrNull(offsets[7]);
  object.payloadSnapshotJson = reader.readStringOrNull(offsets[8]);
  object.performedAt = reader.readDateTime(offsets[9]);
  object.performedByName = reader.readStringOrNull(offsets[10]);
  object.performedByUid = reader.readStringOrNull(offsets[11]);
  object.reason = reader.readStringOrNull(offsets[12]);
  object.schemaVersion = reader.readLong(offsets[13]);
  object.updatedAt = reader.readDateTime(offsets[14]);
  object.version = reader.readLong(offsets[15]);
  object.versionFirestoreId = reader.readStringOrNull(offsets[16]);
  return object;
}

P _templatePublishAuditDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_TemplatePublishAuditactionValueEnumMap[
              reader.readStringOrNull(offset)] ??
          TemplatePublishAuditAction.created) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (reader.readDateTime(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _TemplatePublishAuditactionEnumValueMap = {
  r'created': r'created',
  r'edited': r'edited',
  r'published': r'published',
  r'retired': r'retired',
  r'restored': r'restored',
  r'archived': r'archived',
};
const _TemplatePublishAuditactionValueEnumMap = {
  r'created': TemplatePublishAuditAction.created,
  r'edited': TemplatePublishAuditAction.edited,
  r'published': TemplatePublishAuditAction.published,
  r'retired': TemplatePublishAuditAction.retired,
  r'restored': TemplatePublishAuditAction.restored,
  r'archived': TemplatePublishAuditAction.archived,
};

Id _templatePublishAuditGetId(TemplatePublishAudit object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _templatePublishAuditGetLinks(
    TemplatePublishAudit object) {
  return [];
}

void _templatePublishAuditAttach(
    IsarCollection<dynamic> col, Id id, TemplatePublishAudit object) {
  object.id = id;
}

extension TemplatePublishAuditQueryWhereSort
    on QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QWhere> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhere>
      anyPerformedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'performedAt'),
      );
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhere>
      anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension TemplatePublishAuditQueryWhere
    on QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QWhereClause> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      packageFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packageFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      packageFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'packageFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      packageFirestoreIdEqualTo(String? packageFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packageFirestoreId',
        value: [packageFirestoreId],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      packageFirestoreIdNotEqualTo(String? packageFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [],
              upper: [packageFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [packageFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [packageFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packageFirestoreId',
              lower: [],
              upper: [packageFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      versionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'versionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      versionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'versionFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      versionFirestoreIdEqualTo(String? versionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'versionFirestoreId',
        value: [versionFirestoreId],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      versionFirestoreIdNotEqualTo(String? versionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionFirestoreId',
              lower: [],
              upper: [versionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionFirestoreId',
              lower: [versionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionFirestoreId',
              lower: [versionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'versionFirestoreId',
              lower: [],
              upper: [versionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      actionEqualTo(TemplatePublishAuditAction action) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'action',
        value: [action],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      actionNotEqualTo(TemplatePublishAuditAction action) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'action',
              lower: [],
              upper: [action],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'action',
              lower: [action],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'action',
              lower: [action],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'action',
              lower: [],
              upper: [action],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      performedAtEqualTo(DateTime performedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'performedAt',
        value: [performedAt],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      performedAtNotEqualTo(DateTime performedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedAt',
              lower: [],
              upper: [performedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedAt',
              lower: [performedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedAt',
              lower: [performedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'performedAt',
              lower: [],
              upper: [performedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      performedAtGreaterThan(
    DateTime performedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'performedAt',
        lower: [performedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      performedAtLessThan(
    DateTime performedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'performedAt',
        lower: [],
        upper: [performedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      performedAtBetween(
    DateTime lowerPerformedAt,
    DateTime upperPerformedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'performedAt',
        lower: [lowerPerformedAt],
        includeLower: includeLower,
        upper: [upperPerformedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterWhereClause>
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

extension TemplatePublishAuditQueryFilter on QueryBuilder<TemplatePublishAudit,
    TemplatePublishAudit, QFilterCondition> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionEqualTo(
    TemplatePublishAuditAction value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionGreaterThan(
    TemplatePublishAuditAction value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionLessThan(
    TemplatePublishAuditAction value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionBetween(
    TemplatePublishAuditAction lower,
    TemplatePublishAuditAction upper, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionStartsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionEndsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      actionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'action',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      actionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'action',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'action',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> actionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'action',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'afterHash',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'afterHash',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'afterHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      afterHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'afterHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      afterHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'afterHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'afterHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> afterHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'afterHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'beforeHash',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'beforeHash',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'beforeHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      beforeHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'beforeHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      beforeHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'beforeHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'beforeHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> beforeHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'beforeHash',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'packageFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'packageFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'packageFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      packageFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'packageFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      packageFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'packageFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packageFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> packageFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'packageFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'payloadSnapshotJson',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'payloadSnapshotJson',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payloadSnapshotJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      payloadSnapshotJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payloadSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      payloadSnapshotJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payloadSnapshotJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> payloadSnapshotJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payloadSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'performedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'performedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'performedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'performedByName',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'performedByName',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameEqualTo(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameGreaterThan(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameLessThan(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameBetween(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameStartsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameEndsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      performedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'performedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      performedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'performedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'performedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'performedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'performedByUid',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidEqualTo(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidGreaterThan(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidLessThan(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidStartsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidEndsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      performedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'performedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      performedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'performedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'performedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> performedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'performedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reason',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reason',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonEqualTo(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonGreaterThan(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonLessThan(
    String? value, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonStartsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonEndsWith(
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      reasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      reasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> reasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> schemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> schemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> schemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'schemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
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

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'versionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'versionFirestoreId',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'versionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      versionFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'versionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
          QAfterFilterCondition>
      versionFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'versionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit,
      QAfterFilterCondition> versionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'versionFirestoreId',
        value: '',
      ));
    });
  }
}

extension TemplatePublishAuditQueryObject on QueryBuilder<TemplatePublishAudit,
    TemplatePublishAudit, QFilterCondition> {}

extension TemplatePublishAuditQueryLinks on QueryBuilder<TemplatePublishAudit,
    TemplatePublishAudit, QFilterCondition> {}

extension TemplatePublishAuditQuerySortBy
    on QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QSortBy> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByAfterHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterHash', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByAfterHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterHash', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByBeforeHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeHash', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByBeforeHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeHash', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPackageFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPackageFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPayloadSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPayloadSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByPerformedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      sortByVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFirestoreId', Sort.desc);
    });
  }
}

extension TemplatePublishAuditQuerySortThenBy
    on QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QSortThenBy> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'action', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByAfterHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterHash', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByAfterHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'afterHash', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByBeforeHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeHash', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByBeforeHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'beforeHash', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPackageFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPackageFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPayloadSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPayloadSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByName', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByPerformedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'performedByUid', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByVersionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QAfterSortBy>
      thenByVersionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionFirestoreId', Sort.desc);
    });
  }
}

extension TemplatePublishAuditQueryWhereDistinct
    on QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct> {
  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByAction({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'action', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByAfterHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'afterHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByBeforeHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'beforeHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByPackageFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'packageFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByPayloadSnapshotJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadSnapshotJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByPerformedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedAt');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByPerformedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByPerformedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'performedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAudit, QDistinct>
      distinctByVersionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }
}

extension TemplatePublishAuditQueryProperty on QueryBuilder<
    TemplatePublishAudit, TemplatePublishAudit, QQueryProperty> {
  QueryBuilder<TemplatePublishAudit, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TemplatePublishAudit, TemplatePublishAuditAction,
      QQueryOperations> actionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'action');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      afterHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'afterHash');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      beforeHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'beforeHash');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<TemplatePublishAudit, bool, QQueryOperations>
      isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<TemplatePublishAudit, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      packageFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'packageFirestoreId');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      payloadSnapshotJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadSnapshotJson');
    });
  }

  QueryBuilder<TemplatePublishAudit, DateTime, QQueryOperations>
      performedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedAt');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      performedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedByName');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      performedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'performedByUid');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      reasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reason');
    });
  }

  QueryBuilder<TemplatePublishAudit, int, QQueryOperations>
      schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<TemplatePublishAudit, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<TemplatePublishAudit, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<TemplatePublishAudit, String?, QQueryOperations>
      versionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionFirestoreId');
    });
  }
}
