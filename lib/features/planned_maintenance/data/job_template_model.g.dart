// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_template_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJobTemplateCollection on Isar {
  IsarCollection<JobTemplate> get jobTemplates => this.collection();
}

const JobTemplateSchema = CollectionSchema(
  name: r'JobTemplate',
  id: 7389994387465344115,
  properties: {
    r'applicableAssetType': PropertySchema(
      id: 0,
      name: r'applicableAssetType',
      type: IsarType.string,
      enumMap: _JobTemplateapplicableAssetTypeEnumValueMap,
    ),
    r'assignedAgencies': PropertySchema(
      id: 1,
      name: r'assignedAgencies',
      type: IsarType.stringList,
    ),
    r'component': PropertySchema(
      id: 2,
      name: r'component',
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
    r'debugLabel': PropertySchema(
      id: 6,
      name: r'debugLabel',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 7,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 8,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 9,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 10,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 11,
      name: r'description',
      type: IsarType.string,
    ),
    r'fieldsJson': PropertySchema(
      id: 12,
      name: r'fieldsJson',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 13,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'hasComponentScope': PropertySchema(
      id: 14,
      name: r'hasComponentScope',
      type: IsarType.bool,
    ),
    r'hierarchyPath': PropertySchema(
      id: 15,
      name: r'hierarchyPath',
      type: IsarType.stringList,
    ),
    r'isActive': PropertySchema(
      id: 16,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 17,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isDeprecated': PropertySchema(
      id: 18,
      name: r'isDeprecated',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 19,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'jobName': PropertySchema(
      id: 20,
      name: r'jobName',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 21,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'subsystem': PropertySchema(
      id: 22,
      name: r'subsystem',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 23,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 24,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _jobTemplateEstimateSize,
  serialize: _jobTemplateSerialize,
  deserialize: _jobTemplateDeserialize,
  deserializeProp: _jobTemplateDeserializeProp,
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
  getId: _jobTemplateGetId,
  getLinks: _jobTemplateGetLinks,
  attach: _jobTemplateAttach,
  version: '3.1.0+1',
);

int _jobTemplateEstimateSize(
  JobTemplate object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.applicableAssetType.name.length * 3;
  bytesCount += 3 + object.assignedAgencies.length * 3;
  {
    for (var i = 0; i < object.assignedAgencies.length; i++) {
      final value = object.assignedAgencies[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.component;
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
  bytesCount += 3 + object.debugLabel.length * 3;
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
  bytesCount += 3 + object.fieldsJson.length * 3;
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final list = object.hierarchyPath;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  bytesCount += 3 + object.jobName.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.subsystem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _jobTemplateSerialize(
  JobTemplate object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.applicableAssetType.name);
  writer.writeStringList(offsets[1], object.assignedAgencies);
  writer.writeString(offsets[2], object.component);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.createdByName);
  writer.writeString(offsets[5], object.createdByUid);
  writer.writeString(offsets[6], object.debugLabel);
  writer.writeString(offsets[7], object.deleteReason);
  writer.writeDateTime(offsets[8], object.deletedAt);
  writer.writeString(offsets[9], object.deletedByName);
  writer.writeString(offsets[10], object.deletedByUid);
  writer.writeString(offsets[11], object.description);
  writer.writeString(offsets[12], object.fieldsJson);
  writer.writeString(offsets[13], object.firestoreId);
  writer.writeBool(offsets[14], object.hasComponentScope);
  writer.writeStringList(offsets[15], object.hierarchyPath);
  writer.writeBool(offsets[16], object.isActive);
  writer.writeBool(offsets[17], object.isDeleted);
  writer.writeBool(offsets[18], object.isDeprecated);
  writer.writeBool(offsets[19], object.isSynced);
  writer.writeString(offsets[20], object.jobName);
  writer.writeString(offsets[21], object.metadataJson);
  writer.writeString(offsets[22], object.subsystem);
  writer.writeDateTime(offsets[23], object.updatedAt);
  writer.writeLong(offsets[24], object.version);
}

JobTemplate _jobTemplateDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JobTemplate();
  object.applicableAssetType = _JobTemplateapplicableAssetTypeValueEnumMap[
          reader.readStringOrNull(offsets[0])] ??
      AssetType.base;
  object.assignedAgencies = reader.readStringList(offsets[1]) ?? [];
  object.component = reader.readStringOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.createdByName = reader.readStringOrNull(offsets[4]);
  object.createdByUid = reader.readStringOrNull(offsets[5]);
  object.deleteReason = reader.readStringOrNull(offsets[7]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[8]);
  object.deletedByName = reader.readStringOrNull(offsets[9]);
  object.deletedByUid = reader.readStringOrNull(offsets[10]);
  object.description = reader.readStringOrNull(offsets[11]);
  object.fieldsJson = reader.readString(offsets[12]);
  object.firestoreId = reader.readStringOrNull(offsets[13]);
  object.hierarchyPath = reader.readStringList(offsets[15]);
  object.id = id;
  object.isActive = reader.readBool(offsets[16]);
  object.isDeleted = reader.readBool(offsets[17]);
  object.isDeprecated = reader.readBool(offsets[18]);
  object.isSynced = reader.readBool(offsets[19]);
  object.jobName = reader.readString(offsets[20]);
  object.metadataJson = reader.readStringOrNull(offsets[21]);
  object.subsystem = reader.readStringOrNull(offsets[22]);
  object.updatedAt = reader.readDateTime(offsets[23]);
  object.version = reader.readLong(offsets[24]);
  return object;
}

P _jobTemplateDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_JobTemplateapplicableAssetTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetType.base) as P;
    case 1:
      return (reader.readStringList(offset) ?? []) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readStringList(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readBool(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readBool(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (reader.readStringOrNull(offset)) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    case 23:
      return (reader.readDateTime(offset)) as P;
    case 24:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _JobTemplateapplicableAssetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
};
const _JobTemplateapplicableAssetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
};

Id _jobTemplateGetId(JobTemplate object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _jobTemplateGetLinks(JobTemplate object) {
  return [];
}

void _jobTemplateAttach(
    IsarCollection<dynamic> col, Id id, JobTemplate object) {
  object.id = id;
}

extension JobTemplateQueryWhereSort
    on QueryBuilder<JobTemplate, JobTemplate, QWhere> {
  QueryBuilder<JobTemplate, JobTemplate, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension JobTemplateQueryWhere
    on QueryBuilder<JobTemplate, JobTemplate, QWhereClause> {
  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> idBetween(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> firestoreIdEqualTo(
      String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> isSyncedEqualTo(
      bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> isSyncedNotEqualTo(
      bool isSynced) {
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> createdAtEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> createdAtNotEqualTo(
      DateTime createdAt) {
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> createdAtLessThan(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> createdAtBetween(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> updatedAtEqualTo(
      DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> updatedAtNotEqualTo(
      DateTime updatedAt) {
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> updatedAtLessThan(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterWhereClause> updatedAtBetween(
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

extension JobTemplateQueryFilter
    on QueryBuilder<JobTemplate, JobTemplate, QFilterCondition> {
  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeEqualTo(
    AssetType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeGreaterThan(
    AssetType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeLessThan(
    AssetType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeBetween(
    AssetType lower,
    AssetType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'applicableAssetType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'applicableAssetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'applicableAssetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'applicableAssetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      applicableAssetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'applicableAssetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assignedAgencies',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assignedAgencies',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedAgencies',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assignedAgencies',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      assignedAgenciesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'component',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      componentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'debugLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'debugLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      debugLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fieldsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fieldsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fieldsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fieldsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      fieldsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fieldsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hasComponentScopeEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasComponentScope',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hierarchyPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hierarchyPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      hierarchyPathLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'hierarchyPath',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> idBetween(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> isActiveEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      isDeprecatedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeprecated',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> isSyncedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      jobNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      jobNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'jobName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> jobNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'jobName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      jobNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      jobNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'subsystem',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subsystem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      subsystemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> versionEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition>
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> versionLessThan(
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

  QueryBuilder<JobTemplate, JobTemplate, QAfterFilterCondition> versionBetween(
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

extension JobTemplateQueryObject
    on QueryBuilder<JobTemplate, JobTemplate, QFilterCondition> {}

extension JobTemplateQueryLinks
    on QueryBuilder<JobTemplate, JobTemplate, QFilterCondition> {}

extension JobTemplateQuerySortBy
    on QueryBuilder<JobTemplate, JobTemplate, QSortBy> {
  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByApplicableAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'applicableAssetType', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByApplicableAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'applicableAssetType', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByFieldsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldsJson', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByFieldsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldsJson', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByHasComponentScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentScope', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByHasComponentScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentScope', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsDeprecated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeprecated', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByIsDeprecatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeprecated', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByJobName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByJobNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension JobTemplateQuerySortThenBy
    on QueryBuilder<JobTemplate, JobTemplate, QSortThenBy> {
  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByApplicableAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'applicableAssetType', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByApplicableAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'applicableAssetType', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByFieldsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldsJson', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByFieldsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldsJson', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByHasComponentScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentScope', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByHasComponentScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentScope', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsDeprecated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeprecated', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByIsDeprecatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeprecated', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByJobName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobName', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByJobNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobName', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension JobTemplateQueryWhereDistinct
    on QueryBuilder<JobTemplate, JobTemplate, QDistinct> {
  QueryBuilder<JobTemplate, JobTemplate, QDistinct>
      distinctByApplicableAssetType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'applicableAssetType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct>
      distinctByAssignedAgencies() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assignedAgencies');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByComponent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'component', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByCreatedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByCreatedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDebugLabel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'debugLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDeleteReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDeletedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDeletedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByFieldsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fieldsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct>
      distinctByHasComponentScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasComponentScope');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByHierarchyPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hierarchyPath');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByIsDeprecated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeprecated');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByJobName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByMetadataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctBySubsystem(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subsystem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<JobTemplate, JobTemplate, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension JobTemplateQueryProperty
    on QueryBuilder<JobTemplate, JobTemplate, QQueryProperty> {
  QueryBuilder<JobTemplate, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JobTemplate, AssetType, QQueryOperations>
      applicableAssetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'applicableAssetType');
    });
  }

  QueryBuilder<JobTemplate, List<String>, QQueryOperations>
      assignedAgenciesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedAgencies');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> componentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'component');
    });
  }

  QueryBuilder<JobTemplate, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<JobTemplate, String, QQueryOperations> debugLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'debugLabel');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<JobTemplate, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<JobTemplate, String, QQueryOperations> fieldsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fieldsJson');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<JobTemplate, bool, QQueryOperations>
      hasComponentScopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasComponentScope');
    });
  }

  QueryBuilder<JobTemplate, List<String>?, QQueryOperations>
      hierarchyPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hierarchyPath');
    });
  }

  QueryBuilder<JobTemplate, bool, QQueryOperations> isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<JobTemplate, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<JobTemplate, bool, QQueryOperations> isDeprecatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeprecated');
    });
  }

  QueryBuilder<JobTemplate, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<JobTemplate, String, QQueryOperations> jobNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobName');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<JobTemplate, String?, QQueryOperations> subsystemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subsystem');
    });
  }

  QueryBuilder<JobTemplate, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<JobTemplate, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJobExecutionCollection on Isar {
  IsarCollection<JobExecution> get jobExecutions => this.collection();
}

const JobExecutionSchema = CollectionSchema(
  name: r'JobExecution',
  id: 8749547484972275668,
  properties: {
    r'actionsJson': PropertySchema(
      id: 0,
      name: r'actionsJson',
      type: IsarType.string,
    ),
    r'assetNumber': PropertySchema(
      id: 1,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetType': PropertySchema(
      id: 2,
      name: r'assetType',
      type: IsarType.string,
      enumMap: _JobExecutionassetTypeEnumValueMap,
    ),
    r'assignedAgencies': PropertySchema(
      id: 3,
      name: r'assignedAgencies',
      type: IsarType.stringList,
    ),
    r'assignedByName': PropertySchema(
      id: 4,
      name: r'assignedByName',
      type: IsarType.string,
    ),
    r'assignedByUid': PropertySchema(
      id: 5,
      name: r'assignedByUid',
      type: IsarType.string,
    ),
    r'cancellationReason': PropertySchema(
      id: 6,
      name: r'cancellationReason',
      type: IsarType.string,
    ),
    r'cancelledAt': PropertySchema(
      id: 7,
      name: r'cancelledAt',
      type: IsarType.dateTime,
    ),
    r'cancelledByName': PropertySchema(
      id: 8,
      name: r'cancelledByName',
      type: IsarType.string,
    ),
    r'cancelledByUid': PropertySchema(
      id: 9,
      name: r'cancelledByUid',
      type: IsarType.string,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 10,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'completedAt': PropertySchema(
      id: 11,
      name: r'completedAt',
      type: IsarType.dateTime,
    ),
    r'completedByName': PropertySchema(
      id: 12,
      name: r'completedByName',
      type: IsarType.string,
    ),
    r'completedByUid': PropertySchema(
      id: 13,
      name: r'completedByUid',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 14,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'deleteReason': PropertySchema(
      id: 15,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 16,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 17,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 18,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 19,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'isCancelled': PropertySchema(
      id: 20,
      name: r'isCancelled',
      type: IsarType.bool,
    ),
    r'isCompleted': PropertySchema(
      id: 21,
      name: r'isCompleted',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 22,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 23,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'laneMappingReview': PropertySchema(
      id: 24,
      name: r'laneMappingReview',
      type: IsarType.bool,
    ),
    r'laneSetFinalizedAt': PropertySchema(
      id: 25,
      name: r'laneSetFinalizedAt',
      type: IsarType.dateTime,
    ),
    r'laneSetFinalizedByName': PropertySchema(
      id: 26,
      name: r'laneSetFinalizedByName',
      type: IsarType.string,
    ),
    r'laneSetFinalizedByUid': PropertySchema(
      id: 27,
      name: r'laneSetFinalizedByUid',
      type: IsarType.string,
    ),
    r'laneSetVersion': PropertySchema(
      id: 28,
      name: r'laneSetVersion',
      type: IsarType.long,
    ),
    r'metadataJson': PropertySchema(
      id: 29,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'parentExecutionFirestoreId': PropertySchema(
      id: 30,
      name: r'parentExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'redAnswerJson': PropertySchema(
      id: 31,
      name: r'redAnswerJson',
      type: IsarType.string,
    ),
    r'remarks': PropertySchema(
      id: 32,
      name: r'remarks',
      type: IsarType.string,
    ),
    r'responsesJson': PropertySchema(
      id: 33,
      name: r'responsesJson',
      type: IsarType.string,
    ),
    r'spawnedRedExecutionFirestoreId': PropertySchema(
      id: 34,
      name: r'spawnedRedExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'teamsInvolved': PropertySchema(
      id: 35,
      name: r'teamsInvolved',
      type: IsarType.stringList,
    ),
    r'templateContentHash': PropertySchema(
      id: 36,
      name: r'templateContentHash',
      type: IsarType.string,
    ),
    r'templateFirestoreId': PropertySchema(
      id: 37,
      name: r'templateFirestoreId',
      type: IsarType.string,
    ),
    r'templateName': PropertySchema(
      id: 38,
      name: r'templateName',
      type: IsarType.string,
    ),
    r'templatePackageCode': PropertySchema(
      id: 39,
      name: r'templatePackageCode',
      type: IsarType.string,
    ),
    r'templatePackageId': PropertySchema(
      id: 40,
      name: r'templatePackageId',
      type: IsarType.string,
    ),
    r'templateVersionId': PropertySchema(
      id: 41,
      name: r'templateVersionId',
      type: IsarType.string,
    ),
    r'templateVersionLabel': PropertySchema(
      id: 42,
      name: r'templateVersionLabel',
      type: IsarType.string,
    ),
    r'templateVersionNumber': PropertySchema(
      id: 43,
      name: r'templateVersionNumber',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 44,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 45,
      name: r'version',
      type: IsarType.long,
    ),
    r'workflowSchemaVersion': PropertySchema(
      id: 46,
      name: r'workflowSchemaVersion',
      type: IsarType.long,
    )
  },
  estimateSize: _jobExecutionEstimateSize,
  serialize: _jobExecutionSerialize,
  deserialize: _jobExecutionDeserialize,
  deserializeProp: _jobExecutionDeserializeProp,
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
    r'templateFirestoreId': IndexSchema(
      id: -3638035790332400624,
      name: r'templateFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templateFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'templatePackageId': IndexSchema(
      id: -2198428456183362458,
      name: r'templatePackageId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templatePackageId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'templateVersionId': IndexSchema(
      id: 8336924092931839295,
      name: r'templateVersionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templateVersionId',
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
    r'isCompleted': IndexSchema(
      id: -7936144632215868537,
      name: r'isCompleted',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isCompleted',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isCancelled': IndexSchema(
      id: 9046873824095663760,
      name: r'isCancelled',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isCancelled',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'laneMappingReview': IndexSchema(
      id: 1128124999150228465,
      name: r'laneMappingReview',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'laneMappingReview',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'parentExecutionFirestoreId': IndexSchema(
      id: 6813288294215407249,
      name: r'parentExecutionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'parentExecutionFirestoreId',
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
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _jobExecutionGetId,
  getLinks: _jobExecutionGetLinks,
  attach: _jobExecutionAttach,
  version: '3.1.0+1',
);

int _jobExecutionEstimateSize(
  JobExecution object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.actionsJson.length * 3;
  bytesCount += 3 + object.assetType.name.length * 3;
  bytesCount += 3 + object.assignedAgencies.length * 3;
  {
    for (var i = 0; i < object.assignedAgencies.length; i++) {
      final value = object.assignedAgencies[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.assignedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.assignedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cancellationReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cancelledByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cancelledByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedByUid;
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
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.laneSetFinalizedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.laneSetFinalizedByUid;
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
    final value = object.parentExecutionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.redAnswerJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.remarks;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.responsesJson.length * 3;
  {
    final value = object.spawnedRedExecutionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.teamsInvolved.length * 3;
  {
    for (var i = 0; i < object.teamsInvolved.length; i++) {
      final value = object.teamsInvolved[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.templateContentHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.templateFirestoreId.length * 3;
  {
    final value = object.templateName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templatePackageCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templatePackageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templateVersionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templateVersionLabel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _jobExecutionSerialize(
  JobExecution object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actionsJson);
  writer.writeLong(offsets[1], object.assetNumber);
  writer.writeString(offsets[2], object.assetType.name);
  writer.writeStringList(offsets[3], object.assignedAgencies);
  writer.writeString(offsets[4], object.assignedByName);
  writer.writeString(offsets[5], object.assignedByUid);
  writer.writeString(offsets[6], object.cancellationReason);
  writer.writeDateTime(offsets[7], object.cancelledAt);
  writer.writeString(offsets[8], object.cancelledByName);
  writer.writeString(offsets[9], object.cancelledByUid);
  writer.writeLong(offsets[10], object.chargeNoAtEvent);
  writer.writeDateTime(offsets[11], object.completedAt);
  writer.writeString(offsets[12], object.completedByName);
  writer.writeString(offsets[13], object.completedByUid);
  writer.writeDateTime(offsets[14], object.createdAt);
  writer.writeString(offsets[15], object.deleteReason);
  writer.writeDateTime(offsets[16], object.deletedAt);
  writer.writeString(offsets[17], object.deletedByName);
  writer.writeString(offsets[18], object.deletedByUid);
  writer.writeString(offsets[19], object.firestoreId);
  writer.writeBool(offsets[20], object.isCancelled);
  writer.writeBool(offsets[21], object.isCompleted);
  writer.writeBool(offsets[22], object.isDeleted);
  writer.writeBool(offsets[23], object.isSynced);
  writer.writeBool(offsets[24], object.laneMappingReview);
  writer.writeDateTime(offsets[25], object.laneSetFinalizedAt);
  writer.writeString(offsets[26], object.laneSetFinalizedByName);
  writer.writeString(offsets[27], object.laneSetFinalizedByUid);
  writer.writeLong(offsets[28], object.laneSetVersion);
  writer.writeString(offsets[29], object.metadataJson);
  writer.writeString(offsets[30], object.parentExecutionFirestoreId);
  writer.writeString(offsets[31], object.redAnswerJson);
  writer.writeString(offsets[32], object.remarks);
  writer.writeString(offsets[33], object.responsesJson);
  writer.writeString(offsets[34], object.spawnedRedExecutionFirestoreId);
  writer.writeStringList(offsets[35], object.teamsInvolved);
  writer.writeString(offsets[36], object.templateContentHash);
  writer.writeString(offsets[37], object.templateFirestoreId);
  writer.writeString(offsets[38], object.templateName);
  writer.writeString(offsets[39], object.templatePackageCode);
  writer.writeString(offsets[40], object.templatePackageId);
  writer.writeString(offsets[41], object.templateVersionId);
  writer.writeString(offsets[42], object.templateVersionLabel);
  writer.writeLong(offsets[43], object.templateVersionNumber);
  writer.writeDateTime(offsets[44], object.updatedAt);
  writer.writeLong(offsets[45], object.version);
  writer.writeLong(offsets[46], object.workflowSchemaVersion);
}

JobExecution _jobExecutionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JobExecution();
  object.actionsJson = reader.readString(offsets[0]);
  object.assetNumber = reader.readLong(offsets[1]);
  object.assetType =
      _JobExecutionassetTypeValueEnumMap[reader.readStringOrNull(offsets[2])] ??
          AssetType.base;
  object.assignedAgencies = reader.readStringList(offsets[3]) ?? [];
  object.assignedByName = reader.readStringOrNull(offsets[4]);
  object.assignedByUid = reader.readStringOrNull(offsets[5]);
  object.cancellationReason = reader.readStringOrNull(offsets[6]);
  object.cancelledAt = reader.readDateTimeOrNull(offsets[7]);
  object.cancelledByName = reader.readStringOrNull(offsets[8]);
  object.cancelledByUid = reader.readStringOrNull(offsets[9]);
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[10]);
  object.completedAt = reader.readDateTimeOrNull(offsets[11]);
  object.completedByName = reader.readStringOrNull(offsets[12]);
  object.completedByUid = reader.readStringOrNull(offsets[13]);
  object.createdAt = reader.readDateTime(offsets[14]);
  object.deleteReason = reader.readStringOrNull(offsets[15]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[16]);
  object.deletedByName = reader.readStringOrNull(offsets[17]);
  object.deletedByUid = reader.readStringOrNull(offsets[18]);
  object.firestoreId = reader.readStringOrNull(offsets[19]);
  object.id = id;
  object.isCancelled = reader.readBool(offsets[20]);
  object.isCompleted = reader.readBool(offsets[21]);
  object.isDeleted = reader.readBool(offsets[22]);
  object.isSynced = reader.readBool(offsets[23]);
  object.laneMappingReview = reader.readBool(offsets[24]);
  object.laneSetFinalizedAt = reader.readDateTimeOrNull(offsets[25]);
  object.laneSetFinalizedByName = reader.readStringOrNull(offsets[26]);
  object.laneSetFinalizedByUid = reader.readStringOrNull(offsets[27]);
  object.laneSetVersion = reader.readLong(offsets[28]);
  object.metadataJson = reader.readStringOrNull(offsets[29]);
  object.parentExecutionFirestoreId = reader.readStringOrNull(offsets[30]);
  object.redAnswerJson = reader.readStringOrNull(offsets[31]);
  object.remarks = reader.readStringOrNull(offsets[32]);
  object.responsesJson = reader.readString(offsets[33]);
  object.spawnedRedExecutionFirestoreId = reader.readStringOrNull(offsets[34]);
  object.teamsInvolved = reader.readStringList(offsets[35]) ?? [];
  object.templateContentHash = reader.readStringOrNull(offsets[36]);
  object.templateFirestoreId = reader.readString(offsets[37]);
  object.templateName = reader.readStringOrNull(offsets[38]);
  object.templatePackageCode = reader.readStringOrNull(offsets[39]);
  object.templatePackageId = reader.readStringOrNull(offsets[40]);
  object.templateVersionId = reader.readStringOrNull(offsets[41]);
  object.templateVersionLabel = reader.readStringOrNull(offsets[42]);
  object.templateVersionNumber = reader.readLongOrNull(offsets[43]);
  object.updatedAt = reader.readDateTime(offsets[44]);
  object.version = reader.readLong(offsets[45]);
  object.workflowSchemaVersion = reader.readLong(offsets[46]);
  return object;
}

P _jobExecutionDeserializeProp<P>(
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
      return (_JobExecutionassetTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetType.base) as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
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
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readDateTime(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
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
      return (reader.readDateTimeOrNull(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readLong(offset)) as P;
    case 29:
      return (reader.readStringOrNull(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readStringOrNull(offset)) as P;
    case 32:
      return (reader.readStringOrNull(offset)) as P;
    case 33:
      return (reader.readString(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringList(offset) ?? []) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readString(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readStringOrNull(offset)) as P;
    case 40:
      return (reader.readStringOrNull(offset)) as P;
    case 41:
      return (reader.readStringOrNull(offset)) as P;
    case 42:
      return (reader.readStringOrNull(offset)) as P;
    case 43:
      return (reader.readLongOrNull(offset)) as P;
    case 44:
      return (reader.readDateTime(offset)) as P;
    case 45:
      return (reader.readLong(offset)) as P;
    case 46:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _JobExecutionassetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
};
const _JobExecutionassetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
};

Id _jobExecutionGetId(JobExecution object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _jobExecutionGetLinks(JobExecution object) {
  return [];
}

void _jobExecutionAttach(
    IsarCollection<dynamic> col, Id id, JobExecution object) {
  object.id = id;
}

extension JobExecutionQueryWhereSort
    on QueryBuilder<JobExecution, JobExecution, QWhere> {
  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isCompleted'),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyIsCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isCancelled'),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyLaneMappingReview() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'laneMappingReview'),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }
}

extension JobExecutionQueryWhere
    on QueryBuilder<JobExecution, JobExecution, QWhereClause> {
  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> idBetween(
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateFirestoreIdEqualTo(String templateFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateFirestoreId',
        value: [templateFirestoreId],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateFirestoreIdNotEqualTo(String templateFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateFirestoreId',
              lower: [],
              upper: [templateFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateFirestoreId',
              lower: [templateFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateFirestoreId',
              lower: [templateFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateFirestoreId',
              lower: [],
              upper: [templateFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templatePackageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templatePackageId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templatePackageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'templatePackageId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templatePackageIdEqualTo(String? templatePackageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templatePackageId',
        value: [templatePackageId],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templatePackageIdNotEqualTo(String? templatePackageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templatePackageId',
              lower: [],
              upper: [templatePackageId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templatePackageId',
              lower: [templatePackageId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templatePackageId',
              lower: [templatePackageId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templatePackageId',
              lower: [],
              upper: [templatePackageId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateVersionId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'templateVersionId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateVersionIdEqualTo(String? templateVersionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateVersionId',
        value: [templateVersionId],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      templateVersionIdNotEqualTo(String? templateVersionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateVersionId',
              lower: [],
              upper: [templateVersionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateVersionId',
              lower: [templateVersionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateVersionId',
              lower: [templateVersionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateVersionId',
              lower: [],
              upper: [templateVersionId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      isCompletedEqualTo(bool isCompleted) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isCompleted',
        value: [isCompleted],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      isCompletedNotEqualTo(bool isCompleted) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCompleted',
              lower: [],
              upper: [isCompleted],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCompleted',
              lower: [isCompleted],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCompleted',
              lower: [isCompleted],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCompleted',
              lower: [],
              upper: [isCompleted],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      isCancelledEqualTo(bool isCancelled) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isCancelled',
        value: [isCancelled],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      isCancelledNotEqualTo(bool isCancelled) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCancelled',
              lower: [],
              upper: [isCancelled],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCancelled',
              lower: [isCancelled],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCancelled',
              lower: [isCancelled],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isCancelled',
              lower: [],
              upper: [isCancelled],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      laneMappingReviewEqualTo(bool laneMappingReview) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'laneMappingReview',
        value: [laneMappingReview],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      laneMappingReviewNotEqualTo(bool laneMappingReview) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneMappingReview',
              lower: [],
              upper: [laneMappingReview],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneMappingReview',
              lower: [laneMappingReview],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneMappingReview',
              lower: [laneMappingReview],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneMappingReview',
              lower: [],
              upper: [laneMappingReview],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      parentExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'parentExecutionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      parentExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'parentExecutionFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      parentExecutionFirestoreIdEqualTo(String? parentExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'parentExecutionFirestoreId',
        value: [parentExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
      parentExecutionFirestoreIdNotEqualTo(String? parentExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentExecutionFirestoreId',
              lower: [],
              upper: [parentExecutionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentExecutionFirestoreId',
              lower: [parentExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentExecutionFirestoreId',
              lower: [parentExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'parentExecutionFirestoreId',
              lower: [],
              upper: [parentExecutionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> createdAtEqualTo(
      DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> createdAtLessThan(
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> createdAtBetween(
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

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause> isSyncedEqualTo(
      bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterWhereClause>
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
}

extension JobExecutionQueryFilter
    on QueryBuilder<JobExecution, JobExecution, QFilterCondition> {
  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      actionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetNumberGreaterThan(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetNumberLessThan(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetNumberBetween(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeEqualTo(
    AssetType value, {
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeGreaterThan(
    AssetType value, {
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeLessThan(
    AssetType value, {
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeBetween(
    AssetType lower,
    AssetType upper, {
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assignedAgencies',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assignedAgencies',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assignedAgencies',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedAgencies',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assignedAgencies',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedAgenciesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'assignedAgencies',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assignedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assignedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assignedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assignedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assignedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assignedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assignedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assignedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assignedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assignedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assignedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assignedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      assignedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assignedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cancellationReason',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cancellationReason',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cancellationReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cancellationReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cancellationReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancellationReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancellationReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cancellationReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cancelledAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cancelledAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cancelledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cancelledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cancelledAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cancelledByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cancelledByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cancelledByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cancelledByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cancelledByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelledByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cancelledByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cancelledByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cancelledByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cancelledByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cancelledByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cancelledByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cancelledByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      cancelledByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cancelledByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      chargeNoAtEventBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chargeNoAtEvent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'completedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'completedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'completedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'completedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      completedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'completedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition> idBetween(
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      isCancelledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCancelled',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      isCompletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCompleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneMappingReviewEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneMappingReview',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedAt',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedByName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneSetFinalizedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneSetFinalizedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneSetFinalizedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneSetFinalizedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneSetFinalizedByUid',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetFinalizedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneSetFinalizedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneSetFinalizedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetFinalizedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetFinalizedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneSetFinalizedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneSetVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      laneSetVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneSetVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parentExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parentExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parentExecutionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'parentExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'parentExecutionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      parentExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'parentExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'redAnswerJson',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'redAnswerJson',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'redAnswerJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'redAnswerJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'redAnswerJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'redAnswerJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      redAnswerJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'redAnswerJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remarks',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remarks',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      remarksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'responsesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'responsesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'responsesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      responsesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'responsesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'spawnedRedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'spawnedRedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'spawnedRedExecutionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'spawnedRedExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'spawnedRedExecutionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'spawnedRedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      spawnedRedExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'spawnedRedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'teamsInvolved',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'teamsInvolved',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'teamsInvolved',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'teamsInvolved',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      teamsInvolvedLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'teamsInvolved',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateContentHash',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateContentHash',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateContentHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateContentHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateContentHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateContentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateContentHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateContentHash',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templatePackageCode',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templatePackageCode',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templatePackageCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templatePackageCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templatePackageCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templatePackageCode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templatePackageCode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templatePackageId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templatePackageId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templatePackageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templatePackageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templatePackageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateVersionId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateVersionId',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateVersionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateVersionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateVersionLabel',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateVersionLabel',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateVersionLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateVersionLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateVersionLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateVersionLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateVersionNumber',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateVersionNumber',
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateVersionNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      templateVersionNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateVersionNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
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

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      workflowSchemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      workflowSchemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      workflowSchemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterFilterCondition>
      workflowSchemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowSchemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension JobExecutionQueryObject
    on QueryBuilder<JobExecution, JobExecution, QFilterCondition> {}

extension JobExecutionQueryLinks
    on QueryBuilder<JobExecution, JobExecution, QFilterCondition> {}

extension JobExecutionQuerySortBy
    on QueryBuilder<JobExecution, JobExecution, QSortBy> {
  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByAssignedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByAssignedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByAssignedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByAssignedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancellationReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancellationReason', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancellationReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancellationReason', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByCancelledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancelledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancelledByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancelledByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancelledByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCancelledByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCompletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCompletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCompletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByCompletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCancelled', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByIsCancelledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCancelled', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneMappingReview() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneMappingReview', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneMappingReviewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneMappingReview', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetFinalizedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByLaneSetVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByParentExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByParentExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByRedAnswerJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redAnswerJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByRedAnswerJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redAnswerJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByResponsesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByResponsesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortBySpawnedRedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spawnedRedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortBySpawnedRedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spawnedRedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateContentHash', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateContentHash', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplatePackageCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageCode', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplatePackageCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageCode', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionLabel', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionLabel', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionNumber', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByTemplateVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionNumber', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      sortByWorkflowSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.desc);
    });
  }
}

extension JobExecutionQuerySortThenBy
    on QueryBuilder<JobExecution, JobExecution, QSortThenBy> {
  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByAssignedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByAssignedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByAssignedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByAssignedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancellationReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancellationReason', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancellationReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancellationReason', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByCancelledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancelledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancelledByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancelledByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancelledByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCancelledByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cancelledByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCompletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCompletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCompletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCompletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByCompletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCancelled', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByIsCancelledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCancelled', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneMappingReview() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneMappingReview', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneMappingReviewDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneMappingReview', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetFinalizedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetFinalizedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByLaneSetVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneSetVersion', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByParentExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByParentExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByRedAnswerJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redAnswerJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByRedAnswerJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'redAnswerJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByResponsesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByResponsesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenBySpawnedRedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spawnedRedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenBySpawnedRedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spawnedRedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateContentHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateContentHash', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateContentHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateContentHash', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplatePackageCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageCode', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplatePackageCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageCode', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionLabel', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionLabel', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionNumber', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByTemplateVersionNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionNumber', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QAfterSortBy>
      thenByWorkflowSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowSchemaVersion', Sort.desc);
    });
  }
}

extension JobExecutionQueryWhereDistinct
    on QueryBuilder<JobExecution, JobExecution, QDistinct> {
  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByActionsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByAssetType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByAssignedAgencies() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assignedAgencies');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByAssignedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assignedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByAssignedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assignedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByCancellationReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cancellationReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCancelledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cancelledAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCancelledByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cancelledByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCancelledByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cancelledByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCompletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCompletedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCompletedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByDeleteReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByDeletedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByDeletedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByIsCancelled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCancelled');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCompleted');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByLaneMappingReview() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneMappingReview');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByLaneSetFinalizedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByLaneSetFinalizedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByLaneSetFinalizedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetFinalizedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByLaneSetVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneSetVersion');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByMetadataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByParentExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByRedAnswerJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'redAnswerJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByRemarks(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remarks', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByResponsesJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'responsesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctBySpawnedRedExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'spawnedRedExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTeamsInvolved() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'teamsInvolved');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplateContentHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateContentHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplateFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByTemplateName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplatePackageCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templatePackageCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplatePackageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templatePackageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplateVersionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateVersionId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplateVersionLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateVersionLabel',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByTemplateVersionNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateVersionNumber');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<JobExecution, JobExecution, QDistinct>
      distinctByWorkflowSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowSchemaVersion');
    });
  }
}

extension JobExecutionQueryProperty
    on QueryBuilder<JobExecution, JobExecution, QQueryProperty> {
  QueryBuilder<JobExecution, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JobExecution, String, QQueryOperations> actionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionsJson');
    });
  }

  QueryBuilder<JobExecution, int, QQueryOperations> assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<JobExecution, AssetType, QQueryOperations> assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<JobExecution, List<String>, QQueryOperations>
      assignedAgenciesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedAgencies');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      assignedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedByName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      assignedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedByUid');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      cancellationReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cancellationReason');
    });
  }

  QueryBuilder<JobExecution, DateTime?, QQueryOperations>
      cancelledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cancelledAt');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      cancelledByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cancelledByName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      cancelledByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cancelledByUid');
    });
  }

  QueryBuilder<JobExecution, int?, QQueryOperations> chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobExecution, DateTime?, QQueryOperations>
      completedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedAt');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      completedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedByName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      completedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedByUid');
    });
  }

  QueryBuilder<JobExecution, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<JobExecution, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<JobExecution, bool, QQueryOperations> isCancelledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCancelled');
    });
  }

  QueryBuilder<JobExecution, bool, QQueryOperations> isCompletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCompleted');
    });
  }

  QueryBuilder<JobExecution, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<JobExecution, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<JobExecution, bool, QQueryOperations>
      laneMappingReviewProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneMappingReview');
    });
  }

  QueryBuilder<JobExecution, DateTime?, QQueryOperations>
      laneSetFinalizedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedAt');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      laneSetFinalizedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedByName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      laneSetFinalizedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetFinalizedByUid');
    });
  }

  QueryBuilder<JobExecution, int, QQueryOperations> laneSetVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneSetVersion');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      parentExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentExecutionFirestoreId');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      redAnswerJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'redAnswerJson');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> remarksProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remarks');
    });
  }

  QueryBuilder<JobExecution, String, QQueryOperations> responsesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'responsesJson');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      spawnedRedExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'spawnedRedExecutionFirestoreId');
    });
  }

  QueryBuilder<JobExecution, List<String>, QQueryOperations>
      teamsInvolvedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'teamsInvolved');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      templateContentHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateContentHash');
    });
  }

  QueryBuilder<JobExecution, String, QQueryOperations>
      templateFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateFirestoreId');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations> templateNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateName');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      templatePackageCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templatePackageCode');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      templatePackageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templatePackageId');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      templateVersionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateVersionId');
    });
  }

  QueryBuilder<JobExecution, String?, QQueryOperations>
      templateVersionLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateVersionLabel');
    });
  }

  QueryBuilder<JobExecution, int?, QQueryOperations>
      templateVersionNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateVersionNumber');
    });
  }

  QueryBuilder<JobExecution, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<JobExecution, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<JobExecution, int, QQueryOperations>
      workflowSchemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowSchemaVersion');
    });
  }
}
