// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_diary_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJobDiaryEntryCollection on Isar {
  IsarCollection<JobDiaryEntry> get jobDiaryEntrys => this.collection();
}

const JobDiaryEntrySchema = CollectionSchema(
  name: r'JobDiaryEntry',
  id: 3610953931278188100,
  properties: {
    r'actionTaken': PropertySchema(
      id: 0,
      name: r'actionTaken',
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
      enumMap: _JobDiaryEntryassetTypeEnumValueMap,
    ),
    r'blockerStatus': PropertySchema(
      id: 3,
      name: r'blockerStatus',
      type: IsarType.string,
      enumMap: _JobDiaryEntryblockerStatusEnumValueMap,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 4,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'componentGroup': PropertySchema(
      id: 5,
      name: r'componentGroup',
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
    r'deleteReason': PropertySchema(
      id: 9,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 10,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 11,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 12,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'discipline': PropertySchema(
      id: 13,
      name: r'discipline',
      type: IsarType.string,
      enumMap: _JobDiaryEntrydisciplineEnumValueMap,
    ),
    r'firestoreId': PropertySchema(
      id: 14,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'functionalSection': PropertySchema(
      id: 15,
      name: r'functionalSection',
      type: IsarType.string,
    ),
    r'isBlocker': PropertySchema(
      id: 16,
      name: r'isBlocker',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 17,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isHandover': PropertySchema(
      id: 18,
      name: r'isHandover',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 19,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'jobExecutionFirestoreId': PropertySchema(
      id: 20,
      name: r'jobExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'jobExecutionLocalId': PropertySchema(
      id: 21,
      name: r'jobExecutionLocalId',
      type: IsarType.long,
    ),
    r'kind': PropertySchema(
      id: 22,
      name: r'kind',
      type: IsarType.string,
      enumMap: _JobDiaryEntrykindEnumValueMap,
    ),
    r'metadataJson': PropertySchema(
      id: 23,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'moduleInstanceFirestoreId': PropertySchema(
      id: 24,
      name: r'moduleInstanceFirestoreId',
      type: IsarType.string,
    ),
    r'moduleInstanceLocalId': PropertySchema(
      id: 25,
      name: r'moduleInstanceLocalId',
      type: IsarType.long,
    ),
    r'note': PropertySchema(
      id: 26,
      name: r'note',
      type: IsarType.string,
    ),
    r'pendingIssue': PropertySchema(
      id: 27,
      name: r'pendingIssue',
      type: IsarType.string,
    ),
    r'procedureRef': PropertySchema(
      id: 28,
      name: r'procedureRef',
      type: IsarType.string,
    ),
    r'requiresFollowUp': PropertySchema(
      id: 29,
      name: r'requiresFollowUp',
      type: IsarType.bool,
    ),
    r'severity': PropertySchema(
      id: 30,
      name: r'severity',
      type: IsarType.string,
      enumMap: _JobDiaryEntryseverityEnumValueMap,
    ),
    r'tags': PropertySchema(
      id: 31,
      name: r'tags',
      type: IsarType.stringList,
    ),
    r'targetRef': PropertySchema(
      id: 32,
      name: r'targetRef',
      type: IsarType.string,
    ),
    r'templateFirestoreId': PropertySchema(
      id: 33,
      name: r'templateFirestoreId',
      type: IsarType.string,
    ),
    r'templateName': PropertySchema(
      id: 34,
      name: r'templateName',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 35,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 36,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 37,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 38,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 39,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _jobDiaryEntryEstimateSize,
  serialize: _jobDiaryEntrySerialize,
  deserialize: _jobDiaryEntryDeserialize,
  deserializeProp: _jobDiaryEntryDeserializeProp,
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
    r'jobExecutionFirestoreId': IndexSchema(
      id: -4274754955259152555,
      name: r'jobExecutionFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'jobExecutionFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'jobExecutionLocalId': IndexSchema(
      id: 3804470798990043825,
      name: r'jobExecutionLocalId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'jobExecutionLocalId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'moduleInstanceFirestoreId': IndexSchema(
      id: -5087769240638589523,
      name: r'moduleInstanceFirestoreId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'moduleInstanceFirestoreId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'assetType': IndexSchema(
      id: 2557228192997929194,
      name: r'assetType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetType',
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
    r'kind': IndexSchema(
      id: 1484550194077596484,
      name: r'kind',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'kind',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'discipline': IndexSchema(
      id: 582421567173886972,
      name: r'discipline',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'discipline',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'isBlocker': IndexSchema(
      id: 5021214143609183933,
      name: r'isBlocker',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isBlocker',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'isHandover': IndexSchema(
      id: 8680833970749107532,
      name: r'isHandover',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isHandover',
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
  getId: _jobDiaryEntryGetId,
  getLinks: _jobDiaryEntryGetLinks,
  attach: _jobDiaryEntryAttach,
  version: '3.1.0+1',
);

int _jobDiaryEntryEstimateSize(
  JobDiaryEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.actionTaken;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetType.name.length * 3;
  {
    final value = object.blockerStatus;
    if (value != null) {
      bytesCount += 3 + value.name.length * 3;
    }
  }
  {
    final value = object.componentGroup;
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
  bytesCount += 3 + object.discipline.name.length * 3;
  {
    final value = object.firestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.functionalSection;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.jobExecutionFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.kind.name.length * 3;
  {
    final value = object.metadataJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.moduleInstanceFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.note.length * 3;
  {
    final value = object.pendingIssue;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.procedureRef;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.severity.name.length * 3;
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.targetRef;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templateFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templateName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.title;
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

void _jobDiaryEntrySerialize(
  JobDiaryEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.actionTaken);
  writer.writeLong(offsets[1], object.assetNumber);
  writer.writeString(offsets[2], object.assetType.name);
  writer.writeString(offsets[3], object.blockerStatus?.name);
  writer.writeLong(offsets[4], object.chargeNoAtEvent);
  writer.writeString(offsets[5], object.componentGroup);
  writer.writeDateTime(offsets[6], object.createdAt);
  writer.writeString(offsets[7], object.createdByName);
  writer.writeString(offsets[8], object.createdByUid);
  writer.writeString(offsets[9], object.deleteReason);
  writer.writeDateTime(offsets[10], object.deletedAt);
  writer.writeString(offsets[11], object.deletedByName);
  writer.writeString(offsets[12], object.deletedByUid);
  writer.writeString(offsets[13], object.discipline.name);
  writer.writeString(offsets[14], object.firestoreId);
  writer.writeString(offsets[15], object.functionalSection);
  writer.writeBool(offsets[16], object.isBlocker);
  writer.writeBool(offsets[17], object.isDeleted);
  writer.writeBool(offsets[18], object.isHandover);
  writer.writeBool(offsets[19], object.isSynced);
  writer.writeString(offsets[20], object.jobExecutionFirestoreId);
  writer.writeLong(offsets[21], object.jobExecutionLocalId);
  writer.writeString(offsets[22], object.kind.name);
  writer.writeString(offsets[23], object.metadataJson);
  writer.writeString(offsets[24], object.moduleInstanceFirestoreId);
  writer.writeLong(offsets[25], object.moduleInstanceLocalId);
  writer.writeString(offsets[26], object.note);
  writer.writeString(offsets[27], object.pendingIssue);
  writer.writeString(offsets[28], object.procedureRef);
  writer.writeBool(offsets[29], object.requiresFollowUp);
  writer.writeString(offsets[30], object.severity.name);
  writer.writeStringList(offsets[31], object.tags);
  writer.writeString(offsets[32], object.targetRef);
  writer.writeString(offsets[33], object.templateFirestoreId);
  writer.writeString(offsets[34], object.templateName);
  writer.writeString(offsets[35], object.title);
  writer.writeDateTime(offsets[36], object.updatedAt);
  writer.writeString(offsets[37], object.updatedByName);
  writer.writeString(offsets[38], object.updatedByUid);
  writer.writeLong(offsets[39], object.version);
}

JobDiaryEntry _jobDiaryEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JobDiaryEntry();
  object.actionTaken = reader.readStringOrNull(offsets[0]);
  object.assetNumber = reader.readLong(offsets[1]);
  object.assetType = _JobDiaryEntryassetTypeValueEnumMap[
          reader.readStringOrNull(offsets[2])] ??
      AssetType.base;
  object.blockerStatus = _JobDiaryEntryblockerStatusValueEnumMap[
      reader.readStringOrNull(offsets[3])];
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[4]);
  object.componentGroup = reader.readStringOrNull(offsets[5]);
  object.createdAt = reader.readDateTime(offsets[6]);
  object.createdByName = reader.readStringOrNull(offsets[7]);
  object.createdByUid = reader.readStringOrNull(offsets[8]);
  object.deleteReason = reader.readStringOrNull(offsets[9]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[10]);
  object.deletedByName = reader.readStringOrNull(offsets[11]);
  object.deletedByUid = reader.readStringOrNull(offsets[12]);
  object.discipline = _JobDiaryEntrydisciplineValueEnumMap[
          reader.readStringOrNull(offsets[13])] ??
      JobDiaryDiscipline.mechanical;
  object.firestoreId = reader.readStringOrNull(offsets[14]);
  object.functionalSection = reader.readStringOrNull(offsets[15]);
  object.id = id;
  object.isBlocker = reader.readBool(offsets[16]);
  object.isDeleted = reader.readBool(offsets[17]);
  object.isHandover = reader.readBool(offsets[18]);
  object.isSynced = reader.readBool(offsets[19]);
  object.jobExecutionFirestoreId = reader.readStringOrNull(offsets[20]);
  object.jobExecutionLocalId = reader.readLongOrNull(offsets[21]);
  object.kind =
      _JobDiaryEntrykindValueEnumMap[reader.readStringOrNull(offsets[22])] ??
          JobDiaryKind.note;
  object.metadataJson = reader.readStringOrNull(offsets[23]);
  object.moduleInstanceFirestoreId = reader.readStringOrNull(offsets[24]);
  object.moduleInstanceLocalId = reader.readLongOrNull(offsets[25]);
  object.note = reader.readString(offsets[26]);
  object.pendingIssue = reader.readStringOrNull(offsets[27]);
  object.procedureRef = reader.readStringOrNull(offsets[28]);
  object.requiresFollowUp = reader.readBool(offsets[29]);
  object.severity = _JobDiaryEntryseverityValueEnumMap[
          reader.readStringOrNull(offsets[30])] ??
      JobDiarySeverity.low;
  object.tags = reader.readStringList(offsets[31]) ?? [];
  object.targetRef = reader.readStringOrNull(offsets[32]);
  object.templateFirestoreId = reader.readStringOrNull(offsets[33]);
  object.templateName = reader.readStringOrNull(offsets[34]);
  object.title = reader.readStringOrNull(offsets[35]);
  object.updatedAt = reader.readDateTime(offsets[36]);
  object.updatedByName = reader.readStringOrNull(offsets[37]);
  object.updatedByUid = reader.readStringOrNull(offsets[38]);
  object.version = reader.readLong(offsets[39]);
  return object;
}

P _jobDiaryEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (_JobDiaryEntryassetTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetType.base) as P;
    case 3:
      return (_JobDiaryEntryblockerStatusValueEnumMap[
          reader.readStringOrNull(offset)]) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
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
      return (_JobDiaryEntrydisciplineValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobDiaryDiscipline.mechanical) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readBool(offset)) as P;
    case 17:
      return (reader.readBool(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readBool(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readLongOrNull(offset)) as P;
    case 22:
      return (_JobDiaryEntrykindValueEnumMap[reader.readStringOrNull(offset)] ??
          JobDiaryKind.note) as P;
    case 23:
      return (reader.readStringOrNull(offset)) as P;
    case 24:
      return (reader.readStringOrNull(offset)) as P;
    case 25:
      return (reader.readLongOrNull(offset)) as P;
    case 26:
      return (reader.readString(offset)) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readStringOrNull(offset)) as P;
    case 29:
      return (reader.readBool(offset)) as P;
    case 30:
      return (_JobDiaryEntryseverityValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobDiarySeverity.low) as P;
    case 31:
      return (reader.readStringList(offset) ?? []) as P;
    case 32:
      return (reader.readStringOrNull(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readDateTime(offset)) as P;
    case 37:
      return (reader.readStringOrNull(offset)) as P;
    case 38:
      return (reader.readStringOrNull(offset)) as P;
    case 39:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _JobDiaryEntryassetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
};
const _JobDiaryEntryassetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
};
const _JobDiaryEntryblockerStatusEnumValueMap = {
  r'open': r'open',
  r'resolved': r'resolved',
  r'carriedForward': r'carriedForward',
  r'waived': r'waived',
};
const _JobDiaryEntryblockerStatusValueEnumMap = {
  r'open': JobBlockerStatus.open,
  r'resolved': JobBlockerStatus.resolved,
  r'carriedForward': JobBlockerStatus.carriedForward,
  r'waived': JobBlockerStatus.waived,
};
const _JobDiaryEntrydisciplineEnumValueMap = {
  r'mechanical': r'mechanical',
  r'electrical': r'electrical',
  r'instrumentation': r'instrumentation',
  r'operations': r'operations',
  r'shiftInCharge': r'shiftInCharge',
  r'safety': r'safety',
  r'admin': r'admin',
  r'shared': r'shared',
  r'others': r'others',
};
const _JobDiaryEntrydisciplineValueEnumMap = {
  r'mechanical': JobDiaryDiscipline.mechanical,
  r'electrical': JobDiaryDiscipline.electrical,
  r'instrumentation': JobDiaryDiscipline.instrumentation,
  r'operations': JobDiaryDiscipline.operations,
  r'shiftInCharge': JobDiaryDiscipline.shiftInCharge,
  r'safety': JobDiaryDiscipline.safety,
  r'admin': JobDiaryDiscipline.admin,
  r'shared': JobDiaryDiscipline.shared,
  r'others': JobDiaryDiscipline.others,
};
const _JobDiaryEntrykindEnumValueMap = {
  r'note': r'note',
  r'observation': r'observation',
  r'handover': r'handover',
  r'blocker': r'blocker',
  r'correction': r'correction',
};
const _JobDiaryEntrykindValueEnumMap = {
  r'note': JobDiaryKind.note,
  r'observation': JobDiaryKind.observation,
  r'handover': JobDiaryKind.handover,
  r'blocker': JobDiaryKind.blocker,
  r'correction': JobDiaryKind.correction,
};
const _JobDiaryEntryseverityEnumValueMap = {
  r'low': r'low',
  r'medium': r'medium',
  r'high': r'high',
  r'critical': r'critical',
};
const _JobDiaryEntryseverityValueEnumMap = {
  r'low': JobDiarySeverity.low,
  r'medium': JobDiarySeverity.medium,
  r'high': JobDiarySeverity.high,
  r'critical': JobDiarySeverity.critical,
};

Id _jobDiaryEntryGetId(JobDiaryEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _jobDiaryEntryGetLinks(JobDiaryEntry object) {
  return [];
}

void _jobDiaryEntryAttach(
    IsarCollection<dynamic> col, Id id, JobDiaryEntry object) {
  object.id = id;
}

extension JobDiaryEntryQueryWhereSort
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QWhere> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere>
      anyJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'jobExecutionLocalId'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyIsBlocker() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isBlocker'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyIsHandover() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isHandover'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhere> anyIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isDeleted'),
      );
    });
  }
}

extension JobDiaryEntryQueryWhere
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QWhereClause> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> idBetween(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> isSyncedEqualTo(
      bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionFirestoreIdEqualTo(String? jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [jobExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionFirestoreIdNotEqualTo(String? jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [],
              upper: [jobExecutionFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [jobExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [jobExecutionFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionFirestoreId',
              lower: [],
              upper: [jobExecutionFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdEqualTo(int? jobExecutionLocalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [jobExecutionLocalId],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdNotEqualTo(int? jobExecutionLocalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [],
              upper: [jobExecutionLocalId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [jobExecutionLocalId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [jobExecutionLocalId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'jobExecutionLocalId',
              lower: [],
              upper: [jobExecutionLocalId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdGreaterThan(
    int? jobExecutionLocalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [jobExecutionLocalId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdLessThan(
    int? jobExecutionLocalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [],
        upper: [jobExecutionLocalId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      jobExecutionLocalIdBetween(
    int? lowerJobExecutionLocalId,
    int? upperJobExecutionLocalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'jobExecutionLocalId',
        lower: [lowerJobExecutionLocalId],
        includeLower: includeLower,
        upper: [upperJobExecutionLocalId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      moduleInstanceFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleInstanceFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      moduleInstanceFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moduleInstanceFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      moduleInstanceFirestoreIdEqualTo(String? moduleInstanceFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleInstanceFirestoreId',
        value: [moduleInstanceFirestoreId],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      moduleInstanceFirestoreIdNotEqualTo(String? moduleInstanceFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleInstanceFirestoreId',
              lower: [],
              upper: [moduleInstanceFirestoreId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleInstanceFirestoreId',
              lower: [moduleInstanceFirestoreId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleInstanceFirestoreId',
              lower: [moduleInstanceFirestoreId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleInstanceFirestoreId',
              lower: [],
              upper: [moduleInstanceFirestoreId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      assetTypeEqualTo(AssetType assetType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetType',
        value: [assetType],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      assetTypeNotEqualTo(AssetType assetType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetType',
              lower: [],
              upper: [assetType],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetType',
              lower: [assetType],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetType',
              lower: [assetType],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetType',
              lower: [],
              upper: [assetType],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> kindEqualTo(
      JobDiaryKind kind) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'kind',
        value: [kind],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause> kindNotEqualTo(
      JobDiaryKind kind) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind',
              lower: [],
              upper: [kind],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind',
              lower: [kind],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind',
              lower: [kind],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind',
              lower: [],
              upper: [kind],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      disciplineEqualTo(JobDiaryDiscipline discipline) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'discipline',
        value: [discipline],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      disciplineNotEqualTo(JobDiaryDiscipline discipline) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'discipline',
              lower: [],
              upper: [discipline],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'discipline',
              lower: [discipline],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'discipline',
              lower: [discipline],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'discipline',
              lower: [],
              upper: [discipline],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      isBlockerEqualTo(bool isBlocker) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isBlocker',
        value: [isBlocker],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      isBlockerNotEqualTo(bool isBlocker) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isBlocker',
              lower: [],
              upper: [isBlocker],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isBlocker',
              lower: [isBlocker],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isBlocker',
              lower: [isBlocker],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isBlocker',
              lower: [],
              upper: [isBlocker],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      isHandoverEqualTo(bool isHandover) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isHandover',
        value: [isHandover],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      isHandoverNotEqualTo(bool isHandover) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isHandover',
              lower: [],
              upper: [isHandover],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isHandover',
              lower: [isHandover],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isHandover',
              lower: [isHandover],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isHandover',
              lower: [],
              upper: [isHandover],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
      isDeletedEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDeleted',
        value: [isDeleted],
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterWhereClause>
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

extension JobDiaryEntryQueryFilter
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QFilterCondition> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'actionTaken',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'actionTaken',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'actionTaken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actionTaken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actionTaken',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionTaken',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      actionTakenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actionTaken',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'blockerStatus',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'blockerStatus',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusEqualTo(
    JobBlockerStatus? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusGreaterThan(
    JobBlockerStatus? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusLessThan(
    JobBlockerStatus? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusBetween(
    JobBlockerStatus? lower,
    JobBlockerStatus? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'blockerStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'blockerStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'blockerStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'blockerStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      blockerStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'blockerStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'componentGroup',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'componentGroup',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupEqualTo(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupGreaterThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupLessThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'componentGroup',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      componentGroupIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineEqualTo(
    JobDiaryDiscipline value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineGreaterThan(
    JobDiaryDiscipline value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineLessThan(
    JobDiaryDiscipline value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineBetween(
    JobDiaryDiscipline lower,
    JobDiaryDiscipline upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'discipline',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      disciplineIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'functionalSection',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'functionalSection',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionEqualTo(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionGreaterThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionLessThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'functionalSection',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      functionalSectionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> idBetween(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      isBlockerEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBlocker',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      isHandoverEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isHandover',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'jobExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'jobExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobExecutionFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'jobExecutionFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'jobExecutionFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      jobExecutionLocalIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'jobExecutionLocalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> kindEqualTo(
    JobDiaryKind value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindGreaterThan(
    JobDiaryKind value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindLessThan(
    JobDiaryKind value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> kindBetween(
    JobDiaryKind lower,
    JobDiaryKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'kind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'kind',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> kindMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'kind',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      kindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'kind',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'moduleInstanceFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'moduleInstanceFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleInstanceFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleInstanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleInstanceFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleInstanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleInstanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'moduleInstanceLocalId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'moduleInstanceLocalId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleInstanceLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleInstanceLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleInstanceLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      moduleInstanceLocalIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleInstanceLocalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> noteEqualTo(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteGreaterThan(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteLessThan(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> noteBetween(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteStartsWith(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteEndsWith(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition> noteMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pendingIssue',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pendingIssue',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pendingIssue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pendingIssue',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingIssue',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      pendingIssueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pendingIssue',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'procedureRef',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'procedureRef',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'procedureRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'procedureRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'procedureRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      procedureRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'procedureRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      requiresFollowUpEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiresFollowUp',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityEqualTo(
    JobDiarySeverity value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityGreaterThan(
    JobDiarySeverity value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityLessThan(
    JobDiarySeverity value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityBetween(
    JobDiarySeverity lower,
    JobDiarySeverity upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityEndsWith(
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'severity',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'severity',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'severity',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      severityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'severity',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'targetRef',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'targetRef',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetRef',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      targetRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateFirestoreId',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdEqualTo(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdGreaterThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdLessThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      templateNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'title',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'title',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleEqualTo(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleGreaterThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleLessThan(
    String? value, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
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

extension JobDiaryEntryQueryObject
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QFilterCondition> {}

extension JobDiaryEntryQueryLinks
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QFilterCondition> {}

extension JobDiaryEntryQuerySortBy
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QSortBy> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByActionTaken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionTaken', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByActionTakenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionTaken', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByBlockerStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerStatus', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByBlockerStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerStatus', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByIsBlocker() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBlocker', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByIsBlockerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBlocker', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByIsHandover() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHandover', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByIsHandoverDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHandover', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByModuleInstanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByModuleInstanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByModuleInstanceLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByModuleInstanceLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByPendingIssue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByPendingIssueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByProcedureRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'procedureRef', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByProcedureRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'procedureRef', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByRequiresFollowUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByTargetRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByTargetRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension JobDiaryEntryQuerySortThenBy
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QSortThenBy> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByActionTaken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionTaken', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByActionTakenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionTaken', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByBlockerStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerStatus', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByBlockerStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerStatus', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByIsBlocker() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBlocker', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByIsBlockerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBlocker', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByIsHandover() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHandover', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByIsHandoverDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isHandover', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByModuleInstanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByModuleInstanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByModuleInstanceLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByModuleInstanceLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleInstanceLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByPendingIssue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByPendingIssueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByProcedureRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'procedureRef', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByProcedureRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'procedureRef', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByRequiresFollowUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenBySeverity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenBySeverityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'severity', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByTargetRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByTargetRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension JobDiaryEntryQueryWhereDistinct
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> {
  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByActionTaken(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionTaken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByAssetType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByBlockerStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'blockerStatus',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByComponentGroup({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'componentGroup',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByCreatedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByCreatedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByDeleteReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByDeletedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByDeletedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByDiscipline(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'discipline', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByFirestoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByFunctionalSection({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'functionalSection',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByIsBlocker() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isBlocker');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByIsHandover() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isHandover');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByJobExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByKind(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByMetadataJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByModuleInstanceFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleInstanceFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByModuleInstanceLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleInstanceLocalId');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByPendingIssue(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingIssue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByProcedureRef(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'procedureRef', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requiresFollowUp');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctBySeverity(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'severity', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByTargetRef(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRef', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct>
      distinctByTemplateFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByTemplateName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByUpdatedByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByUpdatedByUid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension JobDiaryEntryQueryProperty
    on QueryBuilder<JobDiaryEntry, JobDiaryEntry, QQueryProperty> {
  QueryBuilder<JobDiaryEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations> actionTakenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionTaken');
    });
  }

  QueryBuilder<JobDiaryEntry, int, QQueryOperations> assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<JobDiaryEntry, AssetType, QQueryOperations> assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<JobDiaryEntry, JobBlockerStatus?, QQueryOperations>
      blockerStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'blockerStatus');
    });
  }

  QueryBuilder<JobDiaryEntry, int?, QQueryOperations>
      chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      componentGroupProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'componentGroup');
    });
  }

  QueryBuilder<JobDiaryEntry, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<JobDiaryEntry, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryDiscipline, QQueryOperations>
      disciplineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'discipline');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations> firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      functionalSectionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'functionalSection');
    });
  }

  QueryBuilder<JobDiaryEntry, bool, QQueryOperations> isBlockerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isBlocker');
    });
  }

  QueryBuilder<JobDiaryEntry, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<JobDiaryEntry, bool, QQueryOperations> isHandoverProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isHandover');
    });
  }

  QueryBuilder<JobDiaryEntry, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      jobExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionFirestoreId');
    });
  }

  QueryBuilder<JobDiaryEntry, int?, QQueryOperations>
      jobExecutionLocalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryKind, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      moduleInstanceFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleInstanceFirestoreId');
    });
  }

  QueryBuilder<JobDiaryEntry, int?, QQueryOperations>
      moduleInstanceLocalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleInstanceLocalId');
    });
  }

  QueryBuilder<JobDiaryEntry, String, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      pendingIssueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingIssue');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      procedureRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'procedureRef');
    });
  }

  QueryBuilder<JobDiaryEntry, bool, QQueryOperations>
      requiresFollowUpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requiresFollowUp');
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiarySeverity, QQueryOperations>
      severityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'severity');
    });
  }

  QueryBuilder<JobDiaryEntry, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations> targetRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRef');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      templateFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateFirestoreId');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      templateNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateName');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<JobDiaryEntry, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<JobDiaryEntry, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<JobDiaryEntry, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
