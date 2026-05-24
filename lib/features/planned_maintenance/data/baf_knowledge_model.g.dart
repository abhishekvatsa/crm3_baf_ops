// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baf_knowledge_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBafKnowledgeRowCollection on Isar {
  IsarCollection<BafKnowledgeRow> get bafKnowledgeRows => this.collection();
}

const BafKnowledgeRowSchema = CollectionSchema(
  name: r'BafKnowledgeRow',
  id: 6184583526286388735,
  properties: {
    r'assetFamily': PropertySchema(
      id: 0,
      name: r'assetFamily',
      type: IsarType.string,
    ),
    r'changeSummary': PropertySchema(
      id: 1,
      name: r'changeSummary',
      type: IsarType.string,
    ),
    r'componentGroup': PropertySchema(
      id: 2,
      name: r'componentGroup',
      type: IsarType.string,
    ),
    r'composerReadiness': PropertySchema(
      id: 3,
      name: r'composerReadiness',
      type: IsarType.string,
    ),
    r'confidence': PropertySchema(
      id: 4,
      name: r'confidence',
      type: IsarType.string,
    ),
    r'consultQuestion': PropertySchema(
      id: 5,
      name: r'consultQuestion',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 6,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 7,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 8,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'deviceTags': PropertySchema(
      id: 9,
      name: r'deviceTags',
      type: IsarType.stringList,
    ),
    r'discipline': PropertySchema(
      id: 10,
      name: r'discipline',
      type: IsarType.string,
    ),
    r'frequency': PropertySchema(
      id: 11,
      name: r'frequency',
      type: IsarType.string,
    ),
    r'functionalSection': PropertySchema(
      id: 12,
      name: r'functionalSection',
      type: IsarType.string,
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
    r'lifecycleStatus': PropertySchema(
      id: 15,
      name: r'lifecycleStatus',
      type: IsarType.string,
    ),
    r'matrixVersion': PropertySchema(
      id: 16,
      name: r'matrixVersion',
      type: IsarType.string,
    ),
    r'moduleCandidateCode': PropertySchema(
      id: 17,
      name: r'moduleCandidateCode',
      type: IsarType.string,
    ),
    r'ownerDisciplines': PropertySchema(
      id: 18,
      name: r'ownerDisciplines',
      type: IsarType.stringList,
    ),
    r'partRefs': PropertySchema(
      id: 19,
      name: r'partRefs',
      type: IsarType.stringList,
    ),
    r'procedureRefs': PropertySchema(
      id: 20,
      name: r'procedureRefs',
      type: IsarType.stringList,
    ),
    r'rawJson': PropertySchema(
      id: 21,
      name: r'rawJson',
      type: IsarType.string,
    ),
    r'requiredForClosure': PropertySchema(
      id: 22,
      name: r'requiredForClosure',
      type: IsarType.string,
    ),
    r'resolverImpact': PropertySchema(
      id: 23,
      name: r'resolverImpact',
      type: IsarType.string,
    ),
    r'rowCode': PropertySchema(
      id: 24,
      name: r'rowCode',
      type: IsarType.string,
    ),
    r'safetyClasses': PropertySchema(
      id: 25,
      name: r'safetyClasses',
      type: IsarType.stringList,
    ),
    r'schemaVersion': PropertySchema(
      id: 26,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'sourceManual': PropertySchema(
      id: 27,
      name: r'sourceManual',
      type: IsarType.string,
    ),
    r'sourcePage': PropertySchema(
      id: 28,
      name: r'sourcePage',
      type: IsarType.string,
    ),
    r'sourceType': PropertySchema(
      id: 29,
      name: r'sourceType',
      type: IsarType.string,
    ),
    r'suggestedFields': PropertySchema(
      id: 30,
      name: r'suggestedFields',
      type: IsarType.stringList,
    ),
    r'targetRefs': PropertySchema(
      id: 31,
      name: r'targetRefs',
      type: IsarType.stringList,
    ),
    r'taskText': PropertySchema(
      id: 32,
      name: r'taskText',
      type: IsarType.string,
    ),
    r'taskType': PropertySchema(
      id: 33,
      name: r'taskType',
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
  estimateSize: _bafKnowledgeRowEstimateSize,
  serialize: _bafKnowledgeRowSerialize,
  deserialize: _bafKnowledgeRowDeserialize,
  deserializeProp: _bafKnowledgeRowDeserializeProp,
  idName: r'id',
  indexes: {
    r'rowCode': IndexSchema(
      id: -4818142532862160590,
      name: r'rowCode',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'rowCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _bafKnowledgeRowGetId,
  getLinks: _bafKnowledgeRowGetLinks,
  attach: _bafKnowledgeRowAttach,
  version: '3.1.0+1',
);

int _bafKnowledgeRowEstimateSize(
  BafKnowledgeRow object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.assetFamily.length * 3;
  bytesCount += 3 + object.changeSummary.length * 3;
  bytesCount += 3 + object.componentGroup.length * 3;
  bytesCount += 3 + object.composerReadiness.length * 3;
  bytesCount += 3 + object.confidence.length * 3;
  bytesCount += 3 + object.consultQuestion.length * 3;
  bytesCount += 3 + object.createdByName.length * 3;
  bytesCount += 3 + object.createdByUid.length * 3;
  bytesCount += 3 + object.deviceTags.length * 3;
  {
    for (var i = 0; i < object.deviceTags.length; i++) {
      final value = object.deviceTags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.discipline.length * 3;
  bytesCount += 3 + object.frequency.length * 3;
  bytesCount += 3 + object.functionalSection.length * 3;
  bytesCount += 3 + object.lifecycleStatus.length * 3;
  bytesCount += 3 + object.matrixVersion.length * 3;
  bytesCount += 3 + object.moduleCandidateCode.length * 3;
  bytesCount += 3 + object.ownerDisciplines.length * 3;
  {
    for (var i = 0; i < object.ownerDisciplines.length; i++) {
      final value = object.ownerDisciplines[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.partRefs.length * 3;
  {
    for (var i = 0; i < object.partRefs.length; i++) {
      final value = object.partRefs[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.procedureRefs.length * 3;
  {
    for (var i = 0; i < object.procedureRefs.length; i++) {
      final value = object.procedureRefs[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.rawJson.length * 3;
  bytesCount += 3 + object.requiredForClosure.length * 3;
  bytesCount += 3 + object.resolverImpact.length * 3;
  bytesCount += 3 + object.rowCode.length * 3;
  bytesCount += 3 + object.safetyClasses.length * 3;
  {
    for (var i = 0; i < object.safetyClasses.length; i++) {
      final value = object.safetyClasses[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.sourceManual.length * 3;
  bytesCount += 3 + object.sourcePage.length * 3;
  bytesCount += 3 + object.sourceType.length * 3;
  bytesCount += 3 + object.suggestedFields.length * 3;
  {
    for (var i = 0; i < object.suggestedFields.length; i++) {
      final value = object.suggestedFields[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.targetRefs.length * 3;
  {
    for (var i = 0; i < object.targetRefs.length; i++) {
      final value = object.targetRefs[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.taskText.length * 3;
  bytesCount += 3 + object.taskType.length * 3;
  bytesCount += 3 + object.updatedByName.length * 3;
  bytesCount += 3 + object.updatedByUid.length * 3;
  return bytesCount;
}

void _bafKnowledgeRowSerialize(
  BafKnowledgeRow object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.assetFamily);
  writer.writeString(offsets[1], object.changeSummary);
  writer.writeString(offsets[2], object.componentGroup);
  writer.writeString(offsets[3], object.composerReadiness);
  writer.writeString(offsets[4], object.confidence);
  writer.writeString(offsets[5], object.consultQuestion);
  writer.writeDateTime(offsets[6], object.createdAt);
  writer.writeString(offsets[7], object.createdByName);
  writer.writeString(offsets[8], object.createdByUid);
  writer.writeStringList(offsets[9], object.deviceTags);
  writer.writeString(offsets[10], object.discipline);
  writer.writeString(offsets[11], object.frequency);
  writer.writeString(offsets[12], object.functionalSection);
  writer.writeBool(offsets[13], object.isDeleted);
  writer.writeBool(offsets[14], object.isSynced);
  writer.writeString(offsets[15], object.lifecycleStatus);
  writer.writeString(offsets[16], object.matrixVersion);
  writer.writeString(offsets[17], object.moduleCandidateCode);
  writer.writeStringList(offsets[18], object.ownerDisciplines);
  writer.writeStringList(offsets[19], object.partRefs);
  writer.writeStringList(offsets[20], object.procedureRefs);
  writer.writeString(offsets[21], object.rawJson);
  writer.writeString(offsets[22], object.requiredForClosure);
  writer.writeString(offsets[23], object.resolverImpact);
  writer.writeString(offsets[24], object.rowCode);
  writer.writeStringList(offsets[25], object.safetyClasses);
  writer.writeLong(offsets[26], object.schemaVersion);
  writer.writeString(offsets[27], object.sourceManual);
  writer.writeString(offsets[28], object.sourcePage);
  writer.writeString(offsets[29], object.sourceType);
  writer.writeStringList(offsets[30], object.suggestedFields);
  writer.writeStringList(offsets[31], object.targetRefs);
  writer.writeString(offsets[32], object.taskText);
  writer.writeString(offsets[33], object.taskType);
  writer.writeDateTime(offsets[34], object.updatedAt);
  writer.writeString(offsets[35], object.updatedByName);
  writer.writeString(offsets[36], object.updatedByUid);
  writer.writeLong(offsets[37], object.version);
}

BafKnowledgeRow _bafKnowledgeRowDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BafKnowledgeRow();
  object.assetFamily = reader.readString(offsets[0]);
  object.changeSummary = reader.readString(offsets[1]);
  object.componentGroup = reader.readString(offsets[2]);
  object.composerReadiness = reader.readString(offsets[3]);
  object.confidence = reader.readString(offsets[4]);
  object.consultQuestion = reader.readString(offsets[5]);
  object.createdAt = reader.readDateTime(offsets[6]);
  object.createdByName = reader.readString(offsets[7]);
  object.createdByUid = reader.readString(offsets[8]);
  object.deviceTags = reader.readStringList(offsets[9]) ?? [];
  object.discipline = reader.readString(offsets[10]);
  object.frequency = reader.readString(offsets[11]);
  object.functionalSection = reader.readString(offsets[12]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[13]);
  object.isSynced = reader.readBool(offsets[14]);
  object.lifecycleStatus = reader.readString(offsets[15]);
  object.matrixVersion = reader.readString(offsets[16]);
  object.moduleCandidateCode = reader.readString(offsets[17]);
  object.ownerDisciplines = reader.readStringList(offsets[18]) ?? [];
  object.partRefs = reader.readStringList(offsets[19]) ?? [];
  object.procedureRefs = reader.readStringList(offsets[20]) ?? [];
  object.rawJson = reader.readString(offsets[21]);
  object.requiredForClosure = reader.readString(offsets[22]);
  object.resolverImpact = reader.readString(offsets[23]);
  object.rowCode = reader.readString(offsets[24]);
  object.safetyClasses = reader.readStringList(offsets[25]) ?? [];
  object.schemaVersion = reader.readLong(offsets[26]);
  object.sourceManual = reader.readString(offsets[27]);
  object.sourcePage = reader.readString(offsets[28]);
  object.sourceType = reader.readString(offsets[29]);
  object.suggestedFields = reader.readStringList(offsets[30]) ?? [];
  object.targetRefs = reader.readStringList(offsets[31]) ?? [];
  object.taskText = reader.readString(offsets[32]);
  object.taskType = reader.readString(offsets[33]);
  object.updatedAt = reader.readDateTime(offsets[34]);
  object.updatedByName = reader.readString(offsets[35]);
  object.updatedByUid = reader.readString(offsets[36]);
  object.version = reader.readLong(offsets[37]);
  return object;
}

P _bafKnowledgeRowDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringList(offset) ?? []) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readBool(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readStringList(offset) ?? []) as P;
    case 19:
      return (reader.readStringList(offset) ?? []) as P;
    case 20:
      return (reader.readStringList(offset) ?? []) as P;
    case 21:
      return (reader.readString(offset)) as P;
    case 22:
      return (reader.readString(offset)) as P;
    case 23:
      return (reader.readString(offset)) as P;
    case 24:
      return (reader.readString(offset)) as P;
    case 25:
      return (reader.readStringList(offset) ?? []) as P;
    case 26:
      return (reader.readLong(offset)) as P;
    case 27:
      return (reader.readString(offset)) as P;
    case 28:
      return (reader.readString(offset)) as P;
    case 29:
      return (reader.readString(offset)) as P;
    case 30:
      return (reader.readStringList(offset) ?? []) as P;
    case 31:
      return (reader.readStringList(offset) ?? []) as P;
    case 32:
      return (reader.readString(offset)) as P;
    case 33:
      return (reader.readString(offset)) as P;
    case 34:
      return (reader.readDateTime(offset)) as P;
    case 35:
      return (reader.readString(offset)) as P;
    case 36:
      return (reader.readString(offset)) as P;
    case 37:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bafKnowledgeRowGetId(BafKnowledgeRow object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bafKnowledgeRowGetLinks(BafKnowledgeRow object) {
  return [];
}

void _bafKnowledgeRowAttach(
    IsarCollection<dynamic> col, Id id, BafKnowledgeRow object) {
  object.id = id;
}

extension BafKnowledgeRowByIndex on IsarCollection<BafKnowledgeRow> {
  Future<BafKnowledgeRow?> getByRowCode(String rowCode) {
    return getByIndex(r'rowCode', [rowCode]);
  }

  BafKnowledgeRow? getByRowCodeSync(String rowCode) {
    return getByIndexSync(r'rowCode', [rowCode]);
  }

  Future<bool> deleteByRowCode(String rowCode) {
    return deleteByIndex(r'rowCode', [rowCode]);
  }

  bool deleteByRowCodeSync(String rowCode) {
    return deleteByIndexSync(r'rowCode', [rowCode]);
  }

  Future<List<BafKnowledgeRow?>> getAllByRowCode(List<String> rowCodeValues) {
    final values = rowCodeValues.map((e) => [e]).toList();
    return getAllByIndex(r'rowCode', values);
  }

  List<BafKnowledgeRow?> getAllByRowCodeSync(List<String> rowCodeValues) {
    final values = rowCodeValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'rowCode', values);
  }

  Future<int> deleteAllByRowCode(List<String> rowCodeValues) {
    final values = rowCodeValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'rowCode', values);
  }

  int deleteAllByRowCodeSync(List<String> rowCodeValues) {
    final values = rowCodeValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'rowCode', values);
  }

  Future<Id> putByRowCode(BafKnowledgeRow object) {
    return putByIndex(r'rowCode', object);
  }

  Id putByRowCodeSync(BafKnowledgeRow object, {bool saveLinks = true}) {
    return putByIndexSync(r'rowCode', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRowCode(List<BafKnowledgeRow> objects) {
    return putAllByIndex(r'rowCode', objects);
  }

  List<Id> putAllByRowCodeSync(List<BafKnowledgeRow> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'rowCode', objects, saveLinks: saveLinks);
  }
}

extension BafKnowledgeRowQueryWhereSort
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QWhere> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BafKnowledgeRowQueryWhere
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QWhereClause> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause> idBetween(
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause>
      rowCodeEqualTo(String rowCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'rowCode',
        value: [rowCode],
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterWhereClause>
      rowCodeNotEqualTo(String rowCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rowCode',
              lower: [],
              upper: [rowCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rowCode',
              lower: [rowCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rowCode',
              lower: [rowCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rowCode',
              lower: [],
              upper: [rowCode],
              includeUpper: false,
            ));
      }
    });
  }
}

extension BafKnowledgeRowQueryFilter
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QFilterCondition> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetFamily',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetFamily',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetFamily',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      assetFamilyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetFamily',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'changeSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      changeSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'componentGroup',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'componentGroup',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      componentGroupIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'composerReadiness',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'composerReadiness',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'composerReadiness',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'composerReadiness',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      composerReadinessIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'composerReadiness',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'confidence',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'confidence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'confidence',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'confidence',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      confidenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'confidence',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'consultQuestion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'consultQuestion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'consultQuestion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'consultQuestion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      consultQuestionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'consultQuestion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceTags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceTags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceTags',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceTags',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      deviceTagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'deviceTags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'discipline',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'discipline',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      disciplineIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'frequency',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'frequency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'frequency',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'frequency',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      frequencyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'frequency',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'functionalSection',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'functionalSection',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      functionalSectionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lifecycleStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lifecycleStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lifecycleStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      lifecycleStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lifecycleStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'matrixVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'matrixVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matrixVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      matrixVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'matrixVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleCandidateCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleCandidateCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleCandidateCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCandidateCode',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      moduleCandidateCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleCandidateCode',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerDisciplines',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerDisciplines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerDisciplines',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerDisciplines',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerDisciplines',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      ownerDisciplinesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'ownerDisciplines',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'partRefs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'partRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'partRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'partRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'partRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      partRefsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'partRefs',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      procedureRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      procedureRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'procedureRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      procedureRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      procedureRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rawJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawJson',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requiredForClosure',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'requiredForClosure',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'requiredForClosure',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiredForClosure',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      requiredForClosureIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'requiredForClosure',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolverImpact',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolverImpact',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolverImpact',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolverImpact',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      resolverImpactIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolverImpact',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rowCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rowCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rowCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rowCode',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      rowCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rowCode',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyClasses',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyClasses',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyClasses',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClasses',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyClasses',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      safetyClassesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyClasses',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceManual',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceManual',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceManual',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceManual',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceManualIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceManual',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourcePage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourcePage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourcePage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourcePage',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourcePageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourcePage',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceType',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      sourceTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceType',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'suggestedFields',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'suggestedFields',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'suggestedFields',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'suggestedFields',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'suggestedFields',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      suggestedFieldsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'suggestedFields',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      targetRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      targetRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      targetRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      targetRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'taskText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'taskText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'taskText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskText',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'taskText',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'taskType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'taskType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'taskType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskType',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      taskTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'taskType',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterFilterCondition>
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

extension BafKnowledgeRowQueryObject
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QFilterCondition> {}

extension BafKnowledgeRowQueryLinks
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QFilterCondition> {}

extension BafKnowledgeRowQuerySortBy
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QSortBy> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByAssetFamily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetFamily', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByAssetFamilyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetFamily', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByComposerReadiness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'composerReadiness', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByComposerReadinessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'composerReadiness', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByConsultQuestion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consultQuestion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByConsultQuestionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consultQuestion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByFrequency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByFrequencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByLifecycleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByLifecycleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByMatrixVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByMatrixVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByModuleCandidateCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCandidateCode', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByModuleCandidateCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCandidateCode', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> sortByRawJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawJson', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByRawJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawJson', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByRequiredForClosureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByResolverImpact() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverImpact', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByResolverImpactDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverImpact', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> sortByRowCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rowCode', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByRowCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rowCode', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourceManual() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceManual', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourceManualDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceManual', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourcePage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePage', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourcePageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePage', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByTaskText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskText', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByTaskTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskText', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByTaskType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskType', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByTaskTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskType', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension BafKnowledgeRowQuerySortThenBy
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QSortThenBy> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByAssetFamily() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetFamily', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByAssetFamilyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetFamily', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByComposerReadiness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'composerReadiness', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByComposerReadinessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'composerReadiness', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'confidence', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByConsultQuestion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consultQuestion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByConsultQuestionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consultQuestion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByFrequency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByFrequencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frequency', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByLifecycleStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByLifecycleStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lifecycleStatus', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByMatrixVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByMatrixVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByModuleCandidateCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCandidateCode', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByModuleCandidateCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCandidateCode', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> thenByRawJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawJson', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByRawJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawJson', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByRequiredForClosureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByResolverImpact() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverImpact', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByResolverImpactDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolverImpact', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> thenByRowCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rowCode', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByRowCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rowCode', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourceManual() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceManual', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourceManualDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceManual', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourcePage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePage', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourcePageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourcePage', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourceType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenBySourceTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceType', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByTaskText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskText', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByTaskTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskText', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByTaskType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskType', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByTaskTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskType', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension BafKnowledgeRowQueryWhereDistinct
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> {
  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByAssetFamily({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetFamily', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByChangeSummary({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'changeSummary',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByComponentGroup({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'componentGroup',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByComposerReadiness({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'composerReadiness',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByConfidence({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'confidence', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByConsultQuestion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consultQuestion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByDeviceTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceTags');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByDiscipline({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'discipline', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> distinctByFrequency(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'frequency', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByFunctionalSection({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'functionalSection',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByLifecycleStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lifecycleStatus',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByMatrixVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'matrixVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByModuleCandidateCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleCandidateCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByOwnerDisciplines() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerDisciplines');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByPartRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'partRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByProcedureRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'procedureRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> distinctByRawJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByRequiredForClosure({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requiredForClosure',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByResolverImpact({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolverImpact',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> distinctByRowCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rowCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySafetyClasses() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyClasses');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySourceManual({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceManual', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySourcePage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourcePage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySourceType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctBySuggestedFields() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'suggestedFields');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByTargetRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> distinctByTaskText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taskText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct> distinctByTaskType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taskType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension BafKnowledgeRowQueryProperty
    on QueryBuilder<BafKnowledgeRow, BafKnowledgeRow, QQueryProperty> {
  QueryBuilder<BafKnowledgeRow, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      assetFamilyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetFamily');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      changeSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'changeSummary');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      componentGroupProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'componentGroup');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      composerReadinessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'composerReadiness');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> confidenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'confidence');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      consultQuestionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consultQuestion');
    });
  }

  QueryBuilder<BafKnowledgeRow, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      deviceTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceTags');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> disciplineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'discipline');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> frequencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'frequency');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      functionalSectionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'functionalSection');
    });
  }

  QueryBuilder<BafKnowledgeRow, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<BafKnowledgeRow, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      lifecycleStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lifecycleStatus');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      matrixVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'matrixVersion');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      moduleCandidateCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleCandidateCode');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      ownerDisciplinesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerDisciplines');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      partRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'partRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      procedureRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'procedureRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> rawJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawJson');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      requiredForClosureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requiredForClosure');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      resolverImpactProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolverImpact');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> rowCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rowCode');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      safetyClassesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyClasses');
    });
  }

  QueryBuilder<BafKnowledgeRow, int, QQueryOperations> schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      sourceManualProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceManual');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> sourcePageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourcePage');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> sourceTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceType');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      suggestedFieldsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'suggestedFields');
    });
  }

  QueryBuilder<BafKnowledgeRow, List<String>, QQueryOperations>
      targetRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRefs');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> taskTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taskText');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations> taskTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taskType');
    });
  }

  QueryBuilder<BafKnowledgeRow, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<BafKnowledgeRow, String, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<BafKnowledgeRow, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBafKnowledgeMatrixMetaStoreCollection on Isar {
  IsarCollection<BafKnowledgeMatrixMetaStore>
      get bafKnowledgeMatrixMetaStores => this.collection();
}

const BafKnowledgeMatrixMetaStoreSchema = CollectionSchema(
  name: r'BafKnowledgeMatrixMetaStore',
  id: -4597930498197848453,
  properties: {
    r'changeSummary': PropertySchema(
      id: 0,
      name: r'changeSummary',
      type: IsarType.string,
    ),
    r'cloudUpdatedAt': PropertySchema(
      id: 1,
      name: r'cloudUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'isDeleted': PropertySchema(
      id: 2,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 3,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'knowledgeRowCount': PropertySchema(
      id: 4,
      name: r'knowledgeRowCount',
      type: IsarType.long,
    ),
    r'localCachedAt': PropertySchema(
      id: 5,
      name: r'localCachedAt',
      type: IsarType.dateTime,
    ),
    r'maintenanceManualRef': PropertySchema(
      id: 6,
      name: r'maintenanceManualRef',
      type: IsarType.string,
    ),
    r'matrixVersion': PropertySchema(
      id: 7,
      name: r'matrixVersion',
      type: IsarType.string,
    ),
    r'metaKey': PropertySchema(
      id: 8,
      name: r'metaKey',
      type: IsarType.string,
    ),
    r'note': PropertySchema(
      id: 9,
      name: r'note',
      type: IsarType.string,
    ),
    r'safetyOperationsManualRef': PropertySchema(
      id: 10,
      name: r'safetyOperationsManualRef',
      type: IsarType.string,
    ),
    r'schemaVersion': PropertySchema(
      id: 11,
      name: r'schemaVersion',
      type: IsarType.long,
    ),
    r'source': PropertySchema(
      id: 12,
      name: r'source',
      type: IsarType.string,
    ),
    r'sourceLabel': PropertySchema(
      id: 13,
      name: r'sourceLabel',
      type: IsarType.string,
    ),
    r'tagRowCount': PropertySchema(
      id: 14,
      name: r'tagRowCount',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 15,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 16,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 17,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 18,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _bafKnowledgeMatrixMetaStoreEstimateSize,
  serialize: _bafKnowledgeMatrixMetaStoreSerialize,
  deserialize: _bafKnowledgeMatrixMetaStoreDeserialize,
  deserializeProp: _bafKnowledgeMatrixMetaStoreDeserializeProp,
  idName: r'id',
  indexes: {
    r'metaKey': IndexSchema(
      id: 3075079648484274111,
      name: r'metaKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'metaKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _bafKnowledgeMatrixMetaStoreGetId,
  getLinks: _bafKnowledgeMatrixMetaStoreGetLinks,
  attach: _bafKnowledgeMatrixMetaStoreAttach,
  version: '3.1.0+1',
);

int _bafKnowledgeMatrixMetaStoreEstimateSize(
  BafKnowledgeMatrixMetaStore object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.changeSummary.length * 3;
  bytesCount += 3 + object.maintenanceManualRef.length * 3;
  bytesCount += 3 + object.matrixVersion.length * 3;
  bytesCount += 3 + object.metaKey.length * 3;
  bytesCount += 3 + object.note.length * 3;
  bytesCount += 3 + object.safetyOperationsManualRef.length * 3;
  bytesCount += 3 + object.source.length * 3;
  bytesCount += 3 + object.sourceLabel.length * 3;
  bytesCount += 3 + object.updatedByName.length * 3;
  bytesCount += 3 + object.updatedByUid.length * 3;
  return bytesCount;
}

void _bafKnowledgeMatrixMetaStoreSerialize(
  BafKnowledgeMatrixMetaStore object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.changeSummary);
  writer.writeDateTime(offsets[1], object.cloudUpdatedAt);
  writer.writeBool(offsets[2], object.isDeleted);
  writer.writeBool(offsets[3], object.isSynced);
  writer.writeLong(offsets[4], object.knowledgeRowCount);
  writer.writeDateTime(offsets[5], object.localCachedAt);
  writer.writeString(offsets[6], object.maintenanceManualRef);
  writer.writeString(offsets[7], object.matrixVersion);
  writer.writeString(offsets[8], object.metaKey);
  writer.writeString(offsets[9], object.note);
  writer.writeString(offsets[10], object.safetyOperationsManualRef);
  writer.writeLong(offsets[11], object.schemaVersion);
  writer.writeString(offsets[12], object.source);
  writer.writeString(offsets[13], object.sourceLabel);
  writer.writeLong(offsets[14], object.tagRowCount);
  writer.writeDateTime(offsets[15], object.updatedAt);
  writer.writeString(offsets[16], object.updatedByName);
  writer.writeString(offsets[17], object.updatedByUid);
  writer.writeLong(offsets[18], object.version);
}

BafKnowledgeMatrixMetaStore _bafKnowledgeMatrixMetaStoreDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BafKnowledgeMatrixMetaStore();
  object.changeSummary = reader.readString(offsets[0]);
  object.cloudUpdatedAt = reader.readDateTimeOrNull(offsets[1]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[2]);
  object.isSynced = reader.readBool(offsets[3]);
  object.knowledgeRowCount = reader.readLong(offsets[4]);
  object.localCachedAt = reader.readDateTimeOrNull(offsets[5]);
  object.maintenanceManualRef = reader.readString(offsets[6]);
  object.matrixVersion = reader.readString(offsets[7]);
  object.metaKey = reader.readString(offsets[8]);
  object.note = reader.readString(offsets[9]);
  object.safetyOperationsManualRef = reader.readString(offsets[10]);
  object.schemaVersion = reader.readLong(offsets[11]);
  object.source = reader.readString(offsets[12]);
  object.sourceLabel = reader.readString(offsets[13]);
  object.tagRowCount = reader.readLong(offsets[14]);
  object.updatedAt = reader.readDateTime(offsets[15]);
  object.updatedByName = reader.readString(offsets[16]);
  object.updatedByUid = reader.readString(offsets[17]);
  object.version = reader.readLong(offsets[18]);
  return object;
}

P _bafKnowledgeMatrixMetaStoreDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readDateTime(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bafKnowledgeMatrixMetaStoreGetId(BafKnowledgeMatrixMetaStore object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bafKnowledgeMatrixMetaStoreGetLinks(
    BafKnowledgeMatrixMetaStore object) {
  return [];
}

void _bafKnowledgeMatrixMetaStoreAttach(
    IsarCollection<dynamic> col, Id id, BafKnowledgeMatrixMetaStore object) {
  object.id = id;
}

extension BafKnowledgeMatrixMetaStoreByIndex
    on IsarCollection<BafKnowledgeMatrixMetaStore> {
  Future<BafKnowledgeMatrixMetaStore?> getByMetaKey(String metaKey) {
    return getByIndex(r'metaKey', [metaKey]);
  }

  BafKnowledgeMatrixMetaStore? getByMetaKeySync(String metaKey) {
    return getByIndexSync(r'metaKey', [metaKey]);
  }

  Future<bool> deleteByMetaKey(String metaKey) {
    return deleteByIndex(r'metaKey', [metaKey]);
  }

  bool deleteByMetaKeySync(String metaKey) {
    return deleteByIndexSync(r'metaKey', [metaKey]);
  }

  Future<List<BafKnowledgeMatrixMetaStore?>> getAllByMetaKey(
      List<String> metaKeyValues) {
    final values = metaKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'metaKey', values);
  }

  List<BafKnowledgeMatrixMetaStore?> getAllByMetaKeySync(
      List<String> metaKeyValues) {
    final values = metaKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'metaKey', values);
  }

  Future<int> deleteAllByMetaKey(List<String> metaKeyValues) {
    final values = metaKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'metaKey', values);
  }

  int deleteAllByMetaKeySync(List<String> metaKeyValues) {
    final values = metaKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'metaKey', values);
  }

  Future<Id> putByMetaKey(BafKnowledgeMatrixMetaStore object) {
    return putByIndex(r'metaKey', object);
  }

  Id putByMetaKeySync(BafKnowledgeMatrixMetaStore object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'metaKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMetaKey(List<BafKnowledgeMatrixMetaStore> objects) {
    return putAllByIndex(r'metaKey', objects);
  }

  List<Id> putAllByMetaKeySync(List<BafKnowledgeMatrixMetaStore> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'metaKey', objects, saveLinks: saveLinks);
  }
}

extension BafKnowledgeMatrixMetaStoreQueryWhereSort on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QWhere> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BafKnowledgeMatrixMetaStoreQueryWhere on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QWhereClause> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhereClause> metaKeyEqualTo(String metaKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'metaKey',
        value: [metaKey],
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterWhereClause> metaKeyNotEqualTo(String metaKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'metaKey',
              lower: [],
              upper: [metaKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'metaKey',
              lower: [metaKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'metaKey',
              lower: [metaKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'metaKey',
              lower: [],
              upper: [metaKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension BafKnowledgeMatrixMetaStoreQueryFilter on QueryBuilder<
    BafKnowledgeMatrixMetaStore,
    BafKnowledgeMatrixMetaStore,
    QFilterCondition> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryStartsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryEndsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      changeSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'changeSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      changeSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'changeSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> changeSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'changeSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudUpdatedAt',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudUpdatedAt',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> cloudUpdatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> knowledgeRowCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'knowledgeRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> knowledgeRowCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'knowledgeRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> knowledgeRowCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'knowledgeRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> knowledgeRowCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'knowledgeRowCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localCachedAt',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localCachedAt',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localCachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localCachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localCachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> localCachedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localCachedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maintenanceManualRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      maintenanceManualRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'maintenanceManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      maintenanceManualRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'maintenanceManualRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maintenanceManualRef',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> maintenanceManualRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'maintenanceManualRef',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'matrixVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      matrixVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'matrixVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      matrixVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'matrixVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matrixVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> matrixVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'matrixVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'metaKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      metaKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metaKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      metaKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metaKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metaKey',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> metaKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metaKey',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyOperationsManualRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      safetyOperationsManualRefContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyOperationsManualRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      safetyOperationsManualRefMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyOperationsManualRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyOperationsManualRef',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> safetyOperationsManualRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyOperationsManualRef',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> schemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'schemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'source',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      sourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      sourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'source',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      sourceLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      sourceLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> sourceLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> tagRowCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tagRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> tagRowCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tagRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> tagRowCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tagRowCount',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> tagRowCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tagRowCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameStartsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameEndsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidEqualTo(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidGreaterThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidLessThan(
    String value, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidBetween(
    String lower,
    String upper, {
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidStartsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidEndsWith(
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
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

extension BafKnowledgeMatrixMetaStoreQueryObject on QueryBuilder<
    BafKnowledgeMatrixMetaStore,
    BafKnowledgeMatrixMetaStore,
    QFilterCondition> {}

extension BafKnowledgeMatrixMetaStoreQueryLinks on QueryBuilder<
    BafKnowledgeMatrixMetaStore,
    BafKnowledgeMatrixMetaStore,
    QFilterCondition> {}

extension BafKnowledgeMatrixMetaStoreQuerySortBy on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QSortBy> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByCloudUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByCloudUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByKnowledgeRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'knowledgeRowCount', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByKnowledgeRowCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'knowledgeRowCount', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByLocalCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localCachedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByLocalCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localCachedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMaintenanceManualRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceManualRef', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMaintenanceManualRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceManualRef', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMatrixVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMatrixVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMetaKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metaKey', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByMetaKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metaKey', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySafetyOperationsManualRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyOperationsManualRef', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySafetyOperationsManualRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyOperationsManualRef', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySourceLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLabel', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortBySourceLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLabel', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByTagRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagRowCount', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByTagRowCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagRowCount', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension BafKnowledgeMatrixMetaStoreQuerySortThenBy on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QSortThenBy> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByChangeSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByChangeSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'changeSummary', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByCloudUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByCloudUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByKnowledgeRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'knowledgeRowCount', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByKnowledgeRowCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'knowledgeRowCount', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByLocalCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localCachedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByLocalCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localCachedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMaintenanceManualRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceManualRef', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMaintenanceManualRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maintenanceManualRef', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMatrixVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMatrixVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matrixVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMetaKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metaKey', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByMetaKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metaKey', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySafetyOperationsManualRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyOperationsManualRef', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySafetyOperationsManualRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyOperationsManualRef', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'schemaVersion', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySourceLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLabel', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenBySourceLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLabel', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByTagRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagRowCount', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByTagRowCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tagRowCount', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension BafKnowledgeMatrixMetaStoreQueryWhereDistinct on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QDistinct> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByChangeSummary({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'changeSummary',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByCloudUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudUpdatedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByKnowledgeRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'knowledgeRowCount');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByLocalCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localCachedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByMaintenanceManualRef({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maintenanceManualRef',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByMatrixVersion({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'matrixVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByMetaKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metaKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
          QDistinct>
      distinctBySafetyOperationsManualRef({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyOperationsManualRef',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctBySchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'schemaVersion');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctBySource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'source', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctBySourceLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByTagRowCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tagRowCount');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore,
      QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension BafKnowledgeMatrixMetaStoreQueryProperty on QueryBuilder<
    BafKnowledgeMatrixMetaStore, BafKnowledgeMatrixMetaStore, QQueryProperty> {
  QueryBuilder<BafKnowledgeMatrixMetaStore, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      changeSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'changeSummary');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, DateTime?, QQueryOperations>
      cloudUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudUpdatedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, bool, QQueryOperations>
      isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, int, QQueryOperations>
      knowledgeRowCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'knowledgeRowCount');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, DateTime?, QQueryOperations>
      localCachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localCachedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      maintenanceManualRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maintenanceManualRef');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      matrixVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'matrixVersion');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      metaKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metaKey');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      safetyOperationsManualRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyOperationsManualRef');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, int, QQueryOperations>
      schemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'schemaVersion');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'source');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      sourceLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceLabel');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, int, QQueryOperations>
      tagRowCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tagRowCount');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, String, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<BafKnowledgeMatrixMetaStore, int, QQueryOperations>
      versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
