// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operational_directive_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOperationalDirectiveCollection on Isar {
  IsarCollection<OperationalDirective> get operationalDirectives =>
      this.collection();
}

const OperationalDirectiveSchema = CollectionSchema(
  name: r'OperationalDirective',
  id: 8926677232068899510,
  properties: {
    r'acknowledgedAt': PropertySchema(
      id: 0,
      name: r'acknowledgedAt',
      type: IsarType.dateTime,
    ),
    r'acknowledgedByName': PropertySchema(
      id: 1,
      name: r'acknowledgedByName',
      type: IsarType.string,
    ),
    r'acknowledgedByUid': PropertySchema(
      id: 2,
      name: r'acknowledgedByUid',
      type: IsarType.string,
    ),
    r'assetNumber': PropertySchema(
      id: 3,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetType': PropertySchema(
      id: 4,
      name: r'assetType',
      type: IsarType.string,
      enumMap: _OperationalDirectiveassetTypeEnumValueMap,
    ),
    r'closedAt': PropertySchema(
      id: 5,
      name: r'closedAt',
      type: IsarType.dateTime,
    ),
    r'closedByName': PropertySchema(
      id: 6,
      name: r'closedByName',
      type: IsarType.string,
    ),
    r'closedByUid': PropertySchema(
      id: 7,
      name: r'closedByUid',
      type: IsarType.string,
    ),
    r'closedWithoutAcknowledgement': PropertySchema(
      id: 8,
      name: r'closedWithoutAcknowledgement',
      type: IsarType.bool,
    ),
    r'component': PropertySchema(
      id: 9,
      name: r'component',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 10,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 11,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 12,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'debugLabel': PropertySchema(
      id: 13,
      name: r'debugLabel',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 14,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 15,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 16,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 17,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 18,
      name: r'description',
      type: IsarType.string,
    ),
    r'directedTo': PropertySchema(
      id: 19,
      name: r'directedTo',
      type: IsarType.string,
      enumMap: _OperationalDirectivedirectedToEnumValueMap,
    ),
    r'firestoreId': PropertySchema(
      id: 20,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'hasAssetContext': PropertySchema(
      id: 21,
      name: r'hasAssetContext',
      type: IsarType.bool,
    ),
    r'hasComponentContext': PropertySchema(
      id: 22,
      name: r'hasComponentContext',
      type: IsarType.bool,
    ),
    r'hierarchyPath': PropertySchema(
      id: 23,
      name: r'hierarchyPath',
      type: IsarType.stringList,
    ),
    r'isAcknowledged': PropertySchema(
      id: 24,
      name: r'isAcknowledged',
      type: IsarType.bool,
    ),
    r'isActive': PropertySchema(
      id: 25,
      name: r'isActive',
      type: IsarType.bool,
    ),
    r'isClosed': PropertySchema(
      id: 26,
      name: r'isClosed',
      type: IsarType.bool,
    ),
    r'isDeleted': PropertySchema(
      id: 27,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isOpen': PropertySchema(
      id: 28,
      name: r'isOpen',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 29,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'issuedAt': PropertySchema(
      id: 30,
      name: r'issuedAt',
      type: IsarType.dateTime,
    ),
    r'issuedByName': PropertySchema(
      id: 31,
      name: r'issuedByName',
      type: IsarType.string,
    ),
    r'issuedByUid': PropertySchema(
      id: 32,
      name: r'issuedByUid',
      type: IsarType.string,
    ),
    r'linkedExecutionFirestoreId': PropertySchema(
      id: 33,
      name: r'linkedExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'linkedMaintenanceFirestoreId': PropertySchema(
      id: 34,
      name: r'linkedMaintenanceFirestoreId',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 35,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'priority': PropertySchema(
      id: 36,
      name: r'priority',
      type: IsarType.string,
      enumMap: _OperationalDirectivepriorityEnumValueMap,
    ),
    r'remarks': PropertySchema(
      id: 37,
      name: r'remarks',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 38,
      name: r'status',
      type: IsarType.string,
      enumMap: _OperationalDirectivestatusEnumValueMap,
    ),
    r'subsystem': PropertySchema(
      id: 39,
      name: r'subsystem',
      type: IsarType.string,
    ),
    r'tag': PropertySchema(
      id: 40,
      name: r'tag',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 41,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 42,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'version': PropertySchema(
      id: 43,
      name: r'version',
      type: IsarType.long,
    )
  },
  estimateSize: _operationalDirectiveEstimateSize,
  serialize: _operationalDirectiveSerialize,
  deserialize: _operationalDirectiveDeserialize,
  deserializeProp: _operationalDirectiveDeserializeProp,
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
    r'directedTo': IndexSchema(
      id: -7192304199582410464,
      name: r'directedTo',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'directedTo',
          type: IndexType.hash,
          caseSensitive: true,
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
  getId: _operationalDirectiveGetId,
  getLinks: _operationalDirectiveGetLinks,
  attach: _operationalDirectiveAttach,
  version: '3.1.0+1',
);

int _operationalDirectiveEstimateSize(
  OperationalDirective object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.acknowledgedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.acknowledgedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.assetType;
    if (value != null) {
      bytesCount += 3 + value.name.length * 3;
    }
  }
  {
    final value = object.closedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.closedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
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
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.directedTo.name.length * 3;
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
  {
    final value = object.issuedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.issuedByUid;
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
    final value = object.linkedMaintenanceFirestoreId;
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
  bytesCount += 3 + object.priority.name.length * 3;
  {
    final value = object.remarks;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.name.length * 3;
  {
    final value = object.subsystem;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.tag;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _operationalDirectiveSerialize(
  OperationalDirective object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acknowledgedAt);
  writer.writeString(offsets[1], object.acknowledgedByName);
  writer.writeString(offsets[2], object.acknowledgedByUid);
  writer.writeLong(offsets[3], object.assetNumber);
  writer.writeString(offsets[4], object.assetType?.name);
  writer.writeDateTime(offsets[5], object.closedAt);
  writer.writeString(offsets[6], object.closedByName);
  writer.writeString(offsets[7], object.closedByUid);
  writer.writeBool(offsets[8], object.closedWithoutAcknowledgement);
  writer.writeString(offsets[9], object.component);
  writer.writeDateTime(offsets[10], object.createdAt);
  writer.writeString(offsets[11], object.createdByName);
  writer.writeString(offsets[12], object.createdByUid);
  writer.writeString(offsets[13], object.debugLabel);
  writer.writeString(offsets[14], object.deleteReason);
  writer.writeDateTime(offsets[15], object.deletedAt);
  writer.writeString(offsets[16], object.deletedByName);
  writer.writeString(offsets[17], object.deletedByUid);
  writer.writeString(offsets[18], object.description);
  writer.writeString(offsets[19], object.directedTo.name);
  writer.writeString(offsets[20], object.firestoreId);
  writer.writeBool(offsets[21], object.hasAssetContext);
  writer.writeBool(offsets[22], object.hasComponentContext);
  writer.writeStringList(offsets[23], object.hierarchyPath);
  writer.writeBool(offsets[24], object.isAcknowledged);
  writer.writeBool(offsets[25], object.isActive);
  writer.writeBool(offsets[26], object.isClosed);
  writer.writeBool(offsets[27], object.isDeleted);
  writer.writeBool(offsets[28], object.isOpen);
  writer.writeBool(offsets[29], object.isSynced);
  writer.writeDateTime(offsets[30], object.issuedAt);
  writer.writeString(offsets[31], object.issuedByName);
  writer.writeString(offsets[32], object.issuedByUid);
  writer.writeString(offsets[33], object.linkedExecutionFirestoreId);
  writer.writeString(offsets[34], object.linkedMaintenanceFirestoreId);
  writer.writeString(offsets[35], object.metadataJson);
  writer.writeString(offsets[36], object.priority.name);
  writer.writeString(offsets[37], object.remarks);
  writer.writeString(offsets[38], object.status.name);
  writer.writeString(offsets[39], object.subsystem);
  writer.writeString(offsets[40], object.tag);
  writer.writeString(offsets[41], object.title);
  writer.writeDateTime(offsets[42], object.updatedAt);
  writer.writeLong(offsets[43], object.version);
}

OperationalDirective _operationalDirectiveDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OperationalDirective();
  object.acknowledgedAt = reader.readDateTimeOrNull(offsets[0]);
  object.acknowledgedByName = reader.readStringOrNull(offsets[1]);
  object.acknowledgedByUid = reader.readStringOrNull(offsets[2]);
  object.assetNumber = reader.readLongOrNull(offsets[3]);
  object.assetType = _OperationalDirectiveassetTypeValueEnumMap[
      reader.readStringOrNull(offsets[4])];
  object.closedAt = reader.readDateTimeOrNull(offsets[5]);
  object.closedByName = reader.readStringOrNull(offsets[6]);
  object.closedByUid = reader.readStringOrNull(offsets[7]);
  object.closedWithoutAcknowledgement = reader.readBool(offsets[8]);
  object.component = reader.readStringOrNull(offsets[9]);
  object.createdAt = reader.readDateTime(offsets[10]);
  object.createdByName = reader.readStringOrNull(offsets[11]);
  object.createdByUid = reader.readStringOrNull(offsets[12]);
  object.deleteReason = reader.readStringOrNull(offsets[14]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[15]);
  object.deletedByName = reader.readStringOrNull(offsets[16]);
  object.deletedByUid = reader.readStringOrNull(offsets[17]);
  object.description = reader.readString(offsets[18]);
  object.directedTo = _OperationalDirectivedirectedToValueEnumMap[
          reader.readStringOrNull(offsets[19])] ??
      AppRole.admin;
  object.firestoreId = reader.readStringOrNull(offsets[20]);
  object.hierarchyPath = reader.readStringList(offsets[23]);
  object.id = id;
  object.isActive = reader.readBool(offsets[25]);
  object.isDeleted = reader.readBool(offsets[27]);
  object.isSynced = reader.readBool(offsets[29]);
  object.issuedAt = reader.readDateTimeOrNull(offsets[30]);
  object.issuedByName = reader.readStringOrNull(offsets[31]);
  object.issuedByUid = reader.readStringOrNull(offsets[32]);
  object.linkedExecutionFirestoreId = reader.readStringOrNull(offsets[33]);
  object.linkedMaintenanceFirestoreId = reader.readStringOrNull(offsets[34]);
  object.metadataJson = reader.readStringOrNull(offsets[35]);
  object.priority = _OperationalDirectivepriorityValueEnumMap[
          reader.readStringOrNull(offsets[36])] ??
      DirectivePriority.low;
  object.remarks = reader.readStringOrNull(offsets[37]);
  object.status = _OperationalDirectivestatusValueEnumMap[
          reader.readStringOrNull(offsets[38])] ??
      DirectiveStatus.open;
  object.subsystem = reader.readStringOrNull(offsets[39]);
  object.tag = reader.readStringOrNull(offsets[40]);
  object.title = reader.readString(offsets[41]);
  object.updatedAt = reader.readDateTime(offsets[42]);
  object.version = reader.readLong(offsets[43]);
  return object;
}

P _operationalDirectiveDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (_OperationalDirectiveassetTypeValueEnumMap[
          reader.readStringOrNull(offset)]) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (_OperationalDirectivedirectedToValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AppRole.admin) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readBool(offset)) as P;
    case 22:
      return (reader.readBool(offset)) as P;
    case 23:
      return (reader.readStringList(offset)) as P;
    case 24:
      return (reader.readBool(offset)) as P;
    case 25:
      return (reader.readBool(offset)) as P;
    case 26:
      return (reader.readBool(offset)) as P;
    case 27:
      return (reader.readBool(offset)) as P;
    case 28:
      return (reader.readBool(offset)) as P;
    case 29:
      return (reader.readBool(offset)) as P;
    case 30:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 31:
      return (reader.readStringOrNull(offset)) as P;
    case 32:
      return (reader.readStringOrNull(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (_OperationalDirectivepriorityValueEnumMap[
              reader.readStringOrNull(offset)] ??
          DirectivePriority.low) as P;
    case 37:
      return (reader.readStringOrNull(offset)) as P;
    case 38:
      return (_OperationalDirectivestatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          DirectiveStatus.open) as P;
    case 39:
      return (reader.readStringOrNull(offset)) as P;
    case 40:
      return (reader.readStringOrNull(offset)) as P;
    case 41:
      return (reader.readString(offset)) as P;
    case 42:
      return (reader.readDateTime(offset)) as P;
    case 43:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _OperationalDirectiveassetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
  r'governedCustom': r'governedCustom',
};
const _OperationalDirectiveassetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
  r'governedCustom': AssetType.governedCustom,
};
const _OperationalDirectivedirectedToEnumValueMap = {
  r'admin': r'admin',
  r'si': r'si',
  r'contractSupervisor': r'contractSupervisor',
  r'shiftSupervisor': r'shiftSupervisor',
  r'seniorElectrical': r'seniorElectrical',
  r'seniorMechanical': r'seniorMechanical',
  r'seniorInstrumentation': r'seniorInstrumentation',
  r'seniorRefractory': r'seniorRefractory',
  r'refractory': r'refractory',
  r'operations': r'operations',
};
const _OperationalDirectivedirectedToValueEnumMap = {
  r'admin': AppRole.admin,
  r'si': AppRole.si,
  r'contractSupervisor': AppRole.contractSupervisor,
  r'shiftSupervisor': AppRole.shiftSupervisor,
  r'seniorElectrical': AppRole.seniorElectrical,
  r'seniorMechanical': AppRole.seniorMechanical,
  r'seniorInstrumentation': AppRole.seniorInstrumentation,
  r'seniorRefractory': AppRole.seniorRefractory,
  r'refractory': AppRole.refractory,
  r'operations': AppRole.operations,
};
const _OperationalDirectivepriorityEnumValueMap = {
  r'low': r'low',
  r'medium': r'medium',
  r'high': r'high',
  r'critical': r'critical',
};
const _OperationalDirectivepriorityValueEnumMap = {
  r'low': DirectivePriority.low,
  r'medium': DirectivePriority.medium,
  r'high': DirectivePriority.high,
  r'critical': DirectivePriority.critical,
};
const _OperationalDirectivestatusEnumValueMap = {
  r'open': r'open',
  r'acknowledged': r'acknowledged',
  r'closed': r'closed',
};
const _OperationalDirectivestatusValueEnumMap = {
  r'open': DirectiveStatus.open,
  r'acknowledged': DirectiveStatus.acknowledged,
  r'closed': DirectiveStatus.closed,
};

Id _operationalDirectiveGetId(OperationalDirective object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _operationalDirectiveGetLinks(
    OperationalDirective object) {
  return [];
}

void _operationalDirectiveAttach(
    IsarCollection<dynamic> col, Id id, OperationalDirective object) {
  object.id = id;
}

extension OperationalDirectiveQueryWhereSort
    on QueryBuilder<OperationalDirective, OperationalDirective, QWhere> {
  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhere>
      anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension OperationalDirectiveQueryWhere
    on QueryBuilder<OperationalDirective, OperationalDirective, QWhereClause> {
  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      directedToEqualTo(AppRole directedTo) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'directedTo',
        value: [directedTo],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      directedToNotEqualTo(AppRole directedTo) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directedTo',
              lower: [],
              upper: [directedTo],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directedTo',
              lower: [directedTo],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directedTo',
              lower: [directedTo],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directedTo',
              lower: [],
              upper: [directedTo],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      statusEqualTo(DirectiveStatus status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      statusNotEqualTo(DirectiveStatus status) {
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
      updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterWhereClause>
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

extension OperationalDirectiveQueryFilter on QueryBuilder<OperationalDirective,
    OperationalDirective, QFilterCondition> {
  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      acknowledgedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      acknowledgedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acknowledgedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acknowledgedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      acknowledgedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acknowledgedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      acknowledgedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acknowledgedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> acknowledgedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acknowledgedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetNumber',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetNumber',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberGreaterThan(
    int? value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberLessThan(
    int? value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetNumberBetween(
    int? lower,
    int? upper, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetType',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetType',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeEqualTo(
    AssetType? value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeGreaterThan(
    AssetType? value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeLessThan(
    AssetType? value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeBetween(
    AssetType? lower,
    AssetType? upper, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      closedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      closedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'closedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'closedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      closedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'closedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      closedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'closedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'closedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> closedWithoutAcknowledgementEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'closedWithoutAcknowledgement',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'component',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      componentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'component',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      componentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'component',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> componentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'component',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      debugLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'debugLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      debugLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'debugLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> debugLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'debugLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedAtBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionEqualTo(
    String value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionGreaterThan(
    String value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionLessThan(
    String value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionBetween(
    String lower,
    String upper, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToEqualTo(
    AppRole value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToGreaterThan(
    AppRole value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToLessThan(
    AppRole value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToBetween(
    AppRole lower,
    AppRole upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'directedTo',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      directedToContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'directedTo',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      directedToMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'directedTo',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'directedTo',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> directedToIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'directedTo',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hasAssetContextEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasAssetContext',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hasComponentContextEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasComponentContext',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'hierarchyPath',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      hierarchyPathElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hierarchyPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      hierarchyPathElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hierarchyPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hierarchyPath',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathLengthEqualTo(int length) {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathIsEmpty() {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathIsNotEmpty() {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathLengthLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathLengthGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> hierarchyPathLengthBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isAcknowledgedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAcknowledged',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isActive',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isClosedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isClosed',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isOpenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isOpen',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'issuedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'issuedAt',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'issuedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'issuedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'issuedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'issuedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'issuedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'issuedByName',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'issuedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      issuedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'issuedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      issuedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'issuedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'issuedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'issuedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'issuedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'issuedByUid',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'issuedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      issuedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'issuedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      issuedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'issuedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'issuedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> issuedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'issuedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'linkedMaintenanceFirestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'linkedMaintenanceFirestoreId',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'linkedMaintenanceFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      linkedMaintenanceFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'linkedMaintenanceFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      linkedMaintenanceFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'linkedMaintenanceFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'linkedMaintenanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> linkedMaintenanceFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'linkedMaintenanceFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityEqualTo(
    DirectivePriority value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityGreaterThan(
    DirectivePriority value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityLessThan(
    DirectivePriority value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityBetween(
    DirectivePriority lower,
    DirectivePriority upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'priority',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      priorityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'priority',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      priorityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'priority',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'priority',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> priorityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'priority',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remarks',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      remarksContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remarks',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      remarksMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remarks',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> remarksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remarks',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusEqualTo(
    DirectiveStatus value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusGreaterThan(
    DirectiveStatus value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusLessThan(
    DirectiveStatus value, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusBetween(
    DirectiveStatus lower,
    DirectiveStatus upper, {
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      subsystemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      subsystemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subsystem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> subsystemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tag',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tag',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tag',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      tagContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      tagMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tag',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tag',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> tagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tag',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleEqualTo(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleGreaterThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleLessThan(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleBetween(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleStartsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleEndsWith(
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

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
          QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
      QAfterFilterCondition> versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

  QueryBuilder<OperationalDirective, OperationalDirective,
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

extension OperationalDirectiveQueryObject on QueryBuilder<OperationalDirective,
    OperationalDirective, QFilterCondition> {}

extension OperationalDirectiveQueryLinks on QueryBuilder<OperationalDirective,
    OperationalDirective, QFilterCondition> {}

extension OperationalDirectiveQuerySortBy
    on QueryBuilder<OperationalDirective, OperationalDirective, QSortBy> {
  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedWithoutAcknowledgement() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedWithoutAcknowledgement', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByClosedWithoutAcknowledgementDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedWithoutAcknowledgement', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDirectedTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directedTo', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByDirectedToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directedTo', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByHasAssetContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAssetContext', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByHasAssetContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAssetContext', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByHasComponentContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsAcknowledged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAcknowledged', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsAcknowledgedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAcknowledged', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsOpenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByIssuedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByLinkedMaintenanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByLinkedMaintenanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension OperationalDirectiveQuerySortThenBy
    on QueryBuilder<OperationalDirective, OperationalDirective, QSortThenBy> {
  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAcknowledgedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acknowledgedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedWithoutAcknowledgement() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedWithoutAcknowledgement', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByClosedWithoutAcknowledgementDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'closedWithoutAcknowledgement', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByComponent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByComponentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'component', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDebugLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDebugLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'debugLabel', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDirectedTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directedTo', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByDirectedToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directedTo', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByHasAssetContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAssetContext', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByHasAssetContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasAssetContext', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByHasComponentContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasComponentContext', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsAcknowledged() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAcknowledged', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsAcknowledgedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAcknowledged', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsClosedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isClosed', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsOpenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOpen', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByName', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByName', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByUid', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByIssuedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'issuedByUid', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByLinkedExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByLinkedExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByLinkedMaintenanceFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByLinkedMaintenanceFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'linkedMaintenanceFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByRemarks() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByRemarksDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remarks', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tag', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension OperationalDirectiveQueryWhereDistinct
    on QueryBuilder<OperationalDirective, OperationalDirective, QDistinct> {
  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByAcknowledgedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByAcknowledgedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByAcknowledgedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acknowledgedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByAssetType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByClosedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByClosedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByClosedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByClosedWithoutAcknowledgement() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'closedWithoutAcknowledgement');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByComponent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'component', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDebugLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'debugLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByDirectedTo({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'directedTo', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByHasAssetContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasAssetContext');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByHasComponentContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasComponentContext');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByHierarchyPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hierarchyPath');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsAcknowledged() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAcknowledged');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsClosed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isClosed');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsOpen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOpen');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIssuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'issuedAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIssuedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'issuedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByIssuedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'issuedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByLinkedExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByLinkedMaintenanceFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'linkedMaintenanceFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByPriority({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'priority', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByRemarks({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remarks', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctBySubsystem({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subsystem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByTag({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<OperationalDirective, OperationalDirective, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension OperationalDirectiveQueryProperty on QueryBuilder<
    OperationalDirective, OperationalDirective, QQueryProperty> {
  QueryBuilder<OperationalDirective, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OperationalDirective, DateTime?, QQueryOperations>
      acknowledgedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedAt');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      acknowledgedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByName');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      acknowledgedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acknowledgedByUid');
    });
  }

  QueryBuilder<OperationalDirective, int?, QQueryOperations>
      assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<OperationalDirective, AssetType?, QQueryOperations>
      assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<OperationalDirective, DateTime?, QQueryOperations>
      closedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedAt');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      closedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByName');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      closedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedByUid');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      closedWithoutAcknowledgementProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'closedWithoutAcknowledgement');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      componentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'component');
    });
  }

  QueryBuilder<OperationalDirective, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<OperationalDirective, String, QQueryOperations>
      debugLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'debugLabel');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<OperationalDirective, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<OperationalDirective, String, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<OperationalDirective, AppRole, QQueryOperations>
      directedToProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'directedTo');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      hasAssetContextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasAssetContext');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      hasComponentContextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasComponentContext');
    });
  }

  QueryBuilder<OperationalDirective, List<String>?, QQueryOperations>
      hierarchyPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hierarchyPath');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      isAcknowledgedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAcknowledged');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      isClosedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isClosed');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations> isOpenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOpen');
    });
  }

  QueryBuilder<OperationalDirective, bool, QQueryOperations>
      isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<OperationalDirective, DateTime?, QQueryOperations>
      issuedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'issuedAt');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      issuedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'issuedByName');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      issuedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'issuedByUid');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      linkedExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedExecutionFirestoreId');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      linkedMaintenanceFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'linkedMaintenanceFirestoreId');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<OperationalDirective, DirectivePriority, QQueryOperations>
      priorityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'priority');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      remarksProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remarks');
    });
  }

  QueryBuilder<OperationalDirective, DirectiveStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations>
      subsystemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subsystem');
    });
  }

  QueryBuilder<OperationalDirective, String?, QQueryOperations> tagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tag');
    });
  }

  QueryBuilder<OperationalDirective, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<OperationalDirective, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<OperationalDirective, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
