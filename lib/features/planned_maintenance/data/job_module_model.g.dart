// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_module_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetJobModuleInstanceCollection on Isar {
  IsarCollection<JobModuleInstance> get jobModuleInstances => this.collection();
}

const JobModuleInstanceSchema = CollectionSchema(
  name: r'JobModuleInstance',
  id: 1431400483870693323,
  properties: {
    r'acceptanceNote': PropertySchema(
      id: 0,
      name: r'acceptanceNote',
      type: IsarType.string,
    ),
    r'acceptedAt': PropertySchema(
      id: 1,
      name: r'acceptedAt',
      type: IsarType.dateTime,
    ),
    r'acceptedByName': PropertySchema(
      id: 2,
      name: r'acceptedByName',
      type: IsarType.string,
    ),
    r'acceptedByUid': PropertySchema(
      id: 3,
      name: r'acceptedByUid',
      type: IsarType.string,
    ),
    r'actionsJson': PropertySchema(
      id: 4,
      name: r'actionsJson',
      type: IsarType.string,
    ),
    r'addReason': PropertySchema(
      id: 5,
      name: r'addReason',
      type: IsarType.string,
    ),
    r'addedAt': PropertySchema(
      id: 6,
      name: r'addedAt',
      type: IsarType.dateTime,
    ),
    r'addedByName': PropertySchema(
      id: 7,
      name: r'addedByName',
      type: IsarType.string,
    ),
    r'addedByUid': PropertySchema(
      id: 8,
      name: r'addedByUid',
      type: IsarType.string,
    ),
    r'addedDuringExecution': PropertySchema(
      id: 9,
      name: r'addedDuringExecution',
      type: IsarType.bool,
    ),
    r'assetNumber': PropertySchema(
      id: 10,
      name: r'assetNumber',
      type: IsarType.long,
    ),
    r'assetType': PropertySchema(
      id: 11,
      name: r'assetType',
      type: IsarType.string,
      enumMap: _JobModuleInstanceassetTypeEnumValueMap,
    ),
    r'chargeNoAtEvent': PropertySchema(
      id: 12,
      name: r'chargeNoAtEvent',
      type: IsarType.long,
    ),
    r'componentGroup': PropertySchema(
      id: 13,
      name: r'componentGroup',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 14,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdByName': PropertySchema(
      id: 15,
      name: r'createdByName',
      type: IsarType.string,
    ),
    r'createdByUid': PropertySchema(
      id: 16,
      name: r'createdByUid',
      type: IsarType.string,
    ),
    r'deleteReason': PropertySchema(
      id: 17,
      name: r'deleteReason',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 18,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'deletedByName': PropertySchema(
      id: 19,
      name: r'deletedByName',
      type: IsarType.string,
    ),
    r'deletedByUid': PropertySchema(
      id: 20,
      name: r'deletedByUid',
      type: IsarType.string,
    ),
    r'discipline': PropertySchema(
      id: 21,
      name: r'discipline',
      type: IsarType.string,
      enumMap: _JobModuleInstancedisciplineEnumValueMap,
    ),
    r'displayOrder': PropertySchema(
      id: 22,
      name: r'displayOrder',
      type: IsarType.long,
    ),
    r'draftNote': PropertySchema(
      id: 23,
      name: r'draftNote',
      type: IsarType.string,
    ),
    r'fieldDefinitionsJson': PropertySchema(
      id: 24,
      name: r'fieldDefinitionsJson',
      type: IsarType.string,
    ),
    r'firestoreId': PropertySchema(
      id: 25,
      name: r'firestoreId',
      type: IsarType.string,
    ),
    r'functionalSection': PropertySchema(
      id: 26,
      name: r'functionalSection',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 27,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isRequired': PropertySchema(
      id: 28,
      name: r'isRequired',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 29,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'jobExecutionFirestoreId': PropertySchema(
      id: 30,
      name: r'jobExecutionFirestoreId',
      type: IsarType.string,
    ),
    r'jobExecutionLocalId': PropertySchema(
      id: 31,
      name: r'jobExecutionLocalId',
      type: IsarType.long,
    ),
    r'laneActivationGeneration': PropertySchema(
      id: 32,
      name: r'laneActivationGeneration',
      type: IsarType.long,
    ),
    r'laneKey': PropertySchema(
      id: 33,
      name: r'laneKey',
      type: IsarType.string,
    ),
    r'metadataJson': PropertySchema(
      id: 34,
      name: r'metadataJson',
      type: IsarType.string,
    ),
    r'moduleCode': PropertySchema(
      id: 35,
      name: r'moduleCode',
      type: IsarType.string,
    ),
    r'moduleDescription': PropertySchema(
      id: 36,
      name: r'moduleDescription',
      type: IsarType.string,
    ),
    r'moduleSnapshotJson': PropertySchema(
      id: 37,
      name: r'moduleSnapshotJson',
      type: IsarType.string,
    ),
    r'moduleTitle': PropertySchema(
      id: 38,
      name: r'moduleTitle',
      type: IsarType.string,
    ),
    r'notApplicableAt': PropertySchema(
      id: 39,
      name: r'notApplicableAt',
      type: IsarType.dateTime,
    ),
    r'notApplicableByName': PropertySchema(
      id: 40,
      name: r'notApplicableByName',
      type: IsarType.string,
    ),
    r'notApplicableByUid': PropertySchema(
      id: 41,
      name: r'notApplicableByUid',
      type: IsarType.string,
    ),
    r'notApplicableReason': PropertySchema(
      id: 42,
      name: r'notApplicableReason',
      type: IsarType.string,
    ),
    r'operationalStatePreconditions': PropertySchema(
      id: 43,
      name: r'operationalStatePreconditions',
      type: IsarType.stringList,
    ),
    r'pairedEquipmentJson': PropertySchema(
      id: 44,
      name: r'pairedEquipmentJson',
      type: IsarType.string,
    ),
    r'pendingIssue': PropertySchema(
      id: 45,
      name: r'pendingIssue',
      type: IsarType.string,
    ),
    r'procedureRefs': PropertySchema(
      id: 46,
      name: r'procedureRefs',
      type: IsarType.stringList,
    ),
    r'reopenReason': PropertySchema(
      id: 47,
      name: r'reopenReason',
      type: IsarType.string,
    ),
    r'reopenedAt': PropertySchema(
      id: 48,
      name: r'reopenedAt',
      type: IsarType.dateTime,
    ),
    r'reopenedByName': PropertySchema(
      id: 49,
      name: r'reopenedByName',
      type: IsarType.string,
    ),
    r'reopenedByUid': PropertySchema(
      id: 50,
      name: r'reopenedByUid',
      type: IsarType.string,
    ),
    r'requiredForClosure': PropertySchema(
      id: 51,
      name: r'requiredForClosure',
      type: IsarType.bool,
    ),
    r'requiresFollowUp': PropertySchema(
      id: 52,
      name: r'requiresFollowUp',
      type: IsarType.bool,
    ),
    r'responsesJson': PropertySchema(
      id: 53,
      name: r'responsesJson',
      type: IsarType.string,
    ),
    r'safetyClass': PropertySchema(
      id: 54,
      name: r'safetyClass',
      type: IsarType.string,
      enumMap: _JobModuleInstancesafetyClassEnumValueMap,
    ),
    r'safetyConfirmations': PropertySchema(
      id: 55,
      name: r'safetyConfirmations',
      type: IsarType.stringList,
    ),
    r'status': PropertySchema(
      id: 56,
      name: r'status',
      type: IsarType.string,
      enumMap: _JobModuleInstancestatusEnumValueMap,
    ),
    r'submissionNote': PropertySchema(
      id: 57,
      name: r'submissionNote',
      type: IsarType.string,
    ),
    r'submittedAt': PropertySchema(
      id: 58,
      name: r'submittedAt',
      type: IsarType.dateTime,
    ),
    r'submittedByName': PropertySchema(
      id: 59,
      name: r'submittedByName',
      type: IsarType.string,
    ),
    r'submittedByUid': PropertySchema(
      id: 60,
      name: r'submittedByUid',
      type: IsarType.string,
    ),
    r'subsystem': PropertySchema(
      id: 61,
      name: r'subsystem',
      type: IsarType.string,
    ),
    r'tags': PropertySchema(
      id: 62,
      name: r'tags',
      type: IsarType.stringList,
    ),
    r'targetRef': PropertySchema(
      id: 63,
      name: r'targetRef',
      type: IsarType.string,
    ),
    r'targetRefs': PropertySchema(
      id: 64,
      name: r'targetRefs',
      type: IsarType.stringList,
    ),
    r'templateFirestoreId': PropertySchema(
      id: 65,
      name: r'templateFirestoreId',
      type: IsarType.string,
    ),
    r'templateModuleId': PropertySchema(
      id: 66,
      name: r'templateModuleId',
      type: IsarType.string,
    ),
    r'templateName': PropertySchema(
      id: 67,
      name: r'templateName',
      type: IsarType.string,
    ),
    r'templatePackageId': PropertySchema(
      id: 68,
      name: r'templatePackageId',
      type: IsarType.string,
    ),
    r'templateVersionId': PropertySchema(
      id: 69,
      name: r'templateVersionId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 70,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'updatedByName': PropertySchema(
      id: 71,
      name: r'updatedByName',
      type: IsarType.string,
    ),
    r'updatedByUid': PropertySchema(
      id: 72,
      name: r'updatedByUid',
      type: IsarType.string,
    ),
    r'useMode': PropertySchema(
      id: 73,
      name: r'useMode',
      type: IsarType.string,
      enumMap: _JobModuleInstanceuseModeEnumValueMap,
    ),
    r'version': PropertySchema(
      id: 74,
      name: r'version',
      type: IsarType.long,
    ),
    r'workflowLaneFirestoreId': PropertySchema(
      id: 75,
      name: r'workflowLaneFirestoreId',
      type: IsarType.string,
    )
  },
  estimateSize: _jobModuleInstanceEstimateSize,
  serialize: _jobModuleInstanceSerialize,
  deserialize: _jobModuleInstanceDeserialize,
  deserializeProp: _jobModuleInstanceDeserializeProp,
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
    r'laneKey': IndexSchema(
      id: 8565663870941351272,
      name: r'laneKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'laneKey',
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
    r'templateModuleId': IndexSchema(
      id: -5100970077828613932,
      name: r'templateModuleId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'templateModuleId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'moduleCode': IndexSchema(
      id: -4649366853241320215,
      name: r'moduleCode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'moduleCode',
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
    r'moduleTitle': IndexSchema(
      id: -1063635279856964618,
      name: r'moduleTitle',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'moduleTitle',
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
    r'useMode': IndexSchema(
      id: 3774057609099801257,
      name: r'useMode',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'useMode',
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
    r'safetyClass': IndexSchema(
      id: -426818609662233417,
      name: r'safetyClass',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'safetyClass',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'isRequired': IndexSchema(
      id: 7011696025255520328,
      name: r'isRequired',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isRequired',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'requiredForClosure': IndexSchema(
      id: 7451253338938818867,
      name: r'requiredForClosure',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'requiredForClosure',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'addedDuringExecution': IndexSchema(
      id: -5817527723139811079,
      name: r'addedDuringExecution',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'addedDuringExecution',
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
  getId: _jobModuleInstanceGetId,
  getLinks: _jobModuleInstanceGetLinks,
  attach: _jobModuleInstanceAttach,
  version: '3.1.0+1',
);

int _jobModuleInstanceEstimateSize(
  JobModuleInstance object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.acceptanceNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.acceptedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.acceptedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.actionsJson.length * 3;
  {
    final value = object.addReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.addedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.addedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.assetType.name.length * 3;
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
    final value = object.draftNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.fieldDefinitionsJson.length * 3;
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
  {
    final value = object.laneKey;
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
    final value = object.moduleCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.moduleDescription;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.moduleSnapshotJson.length * 3;
  bytesCount += 3 + object.moduleTitle.length * 3;
  {
    final value = object.notApplicableByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.notApplicableByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.notApplicableReason;
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
  {
    final value = object.pairedEquipmentJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.pendingIssue;
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
    final value = object.reopenReason;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reopenedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reopenedByUid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.responsesJson.length * 3;
  bytesCount += 3 + object.safetyClass.name.length * 3;
  bytesCount += 3 + object.safetyConfirmations.length * 3;
  {
    for (var i = 0; i < object.safetyConfirmations.length; i++) {
      final value = object.safetyConfirmations[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.status.name.length * 3;
  {
    final value = object.submissionNote;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.submittedByName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.submittedByUid;
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
  bytesCount += 3 + object.targetRefs.length * 3;
  {
    for (var i = 0; i < object.targetRefs.length; i++) {
      final value = object.targetRefs[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.templateFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.templateModuleId;
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
  bytesCount += 3 + object.useMode.name.length * 3;
  {
    final value = object.workflowLaneFirestoreId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _jobModuleInstanceSerialize(
  JobModuleInstance object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.acceptanceNote);
  writer.writeDateTime(offsets[1], object.acceptedAt);
  writer.writeString(offsets[2], object.acceptedByName);
  writer.writeString(offsets[3], object.acceptedByUid);
  writer.writeString(offsets[4], object.actionsJson);
  writer.writeString(offsets[5], object.addReason);
  writer.writeDateTime(offsets[6], object.addedAt);
  writer.writeString(offsets[7], object.addedByName);
  writer.writeString(offsets[8], object.addedByUid);
  writer.writeBool(offsets[9], object.addedDuringExecution);
  writer.writeLong(offsets[10], object.assetNumber);
  writer.writeString(offsets[11], object.assetType.name);
  writer.writeLong(offsets[12], object.chargeNoAtEvent);
  writer.writeString(offsets[13], object.componentGroup);
  writer.writeDateTime(offsets[14], object.createdAt);
  writer.writeString(offsets[15], object.createdByName);
  writer.writeString(offsets[16], object.createdByUid);
  writer.writeString(offsets[17], object.deleteReason);
  writer.writeDateTime(offsets[18], object.deletedAt);
  writer.writeString(offsets[19], object.deletedByName);
  writer.writeString(offsets[20], object.deletedByUid);
  writer.writeString(offsets[21], object.discipline.name);
  writer.writeLong(offsets[22], object.displayOrder);
  writer.writeString(offsets[23], object.draftNote);
  writer.writeString(offsets[24], object.fieldDefinitionsJson);
  writer.writeString(offsets[25], object.firestoreId);
  writer.writeString(offsets[26], object.functionalSection);
  writer.writeBool(offsets[27], object.isDeleted);
  writer.writeBool(offsets[28], object.isRequired);
  writer.writeBool(offsets[29], object.isSynced);
  writer.writeString(offsets[30], object.jobExecutionFirestoreId);
  writer.writeLong(offsets[31], object.jobExecutionLocalId);
  writer.writeLong(offsets[32], object.laneActivationGeneration);
  writer.writeString(offsets[33], object.laneKey);
  writer.writeString(offsets[34], object.metadataJson);
  writer.writeString(offsets[35], object.moduleCode);
  writer.writeString(offsets[36], object.moduleDescription);
  writer.writeString(offsets[37], object.moduleSnapshotJson);
  writer.writeString(offsets[38], object.moduleTitle);
  writer.writeDateTime(offsets[39], object.notApplicableAt);
  writer.writeString(offsets[40], object.notApplicableByName);
  writer.writeString(offsets[41], object.notApplicableByUid);
  writer.writeString(offsets[42], object.notApplicableReason);
  writer.writeStringList(offsets[43], object.operationalStatePreconditions);
  writer.writeString(offsets[44], object.pairedEquipmentJson);
  writer.writeString(offsets[45], object.pendingIssue);
  writer.writeStringList(offsets[46], object.procedureRefs);
  writer.writeString(offsets[47], object.reopenReason);
  writer.writeDateTime(offsets[48], object.reopenedAt);
  writer.writeString(offsets[49], object.reopenedByName);
  writer.writeString(offsets[50], object.reopenedByUid);
  writer.writeBool(offsets[51], object.requiredForClosure);
  writer.writeBool(offsets[52], object.requiresFollowUp);
  writer.writeString(offsets[53], object.responsesJson);
  writer.writeString(offsets[54], object.safetyClass.name);
  writer.writeStringList(offsets[55], object.safetyConfirmations);
  writer.writeString(offsets[56], object.status.name);
  writer.writeString(offsets[57], object.submissionNote);
  writer.writeDateTime(offsets[58], object.submittedAt);
  writer.writeString(offsets[59], object.submittedByName);
  writer.writeString(offsets[60], object.submittedByUid);
  writer.writeString(offsets[61], object.subsystem);
  writer.writeStringList(offsets[62], object.tags);
  writer.writeString(offsets[63], object.targetRef);
  writer.writeStringList(offsets[64], object.targetRefs);
  writer.writeString(offsets[65], object.templateFirestoreId);
  writer.writeString(offsets[66], object.templateModuleId);
  writer.writeString(offsets[67], object.templateName);
  writer.writeString(offsets[68], object.templatePackageId);
  writer.writeString(offsets[69], object.templateVersionId);
  writer.writeDateTime(offsets[70], object.updatedAt);
  writer.writeString(offsets[71], object.updatedByName);
  writer.writeString(offsets[72], object.updatedByUid);
  writer.writeString(offsets[73], object.useMode.name);
  writer.writeLong(offsets[74], object.version);
  writer.writeString(offsets[75], object.workflowLaneFirestoreId);
}

JobModuleInstance _jobModuleInstanceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = JobModuleInstance();
  object.acceptanceNote = reader.readStringOrNull(offsets[0]);
  object.acceptedAt = reader.readDateTimeOrNull(offsets[1]);
  object.acceptedByName = reader.readStringOrNull(offsets[2]);
  object.acceptedByUid = reader.readStringOrNull(offsets[3]);
  object.actionsJson = reader.readString(offsets[4]);
  object.addReason = reader.readStringOrNull(offsets[5]);
  object.addedAt = reader.readDateTimeOrNull(offsets[6]);
  object.addedByName = reader.readStringOrNull(offsets[7]);
  object.addedByUid = reader.readStringOrNull(offsets[8]);
  object.addedDuringExecution = reader.readBool(offsets[9]);
  object.assetNumber = reader.readLong(offsets[10]);
  object.assetType = _JobModuleInstanceassetTypeValueEnumMap[
          reader.readStringOrNull(offsets[11])] ??
      AssetType.base;
  object.chargeNoAtEvent = reader.readLongOrNull(offsets[12]);
  object.componentGroup = reader.readStringOrNull(offsets[13]);
  object.createdAt = reader.readDateTime(offsets[14]);
  object.createdByName = reader.readStringOrNull(offsets[15]);
  object.createdByUid = reader.readStringOrNull(offsets[16]);
  object.deleteReason = reader.readStringOrNull(offsets[17]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[18]);
  object.deletedByName = reader.readStringOrNull(offsets[19]);
  object.deletedByUid = reader.readStringOrNull(offsets[20]);
  object.discipline = _JobModuleInstancedisciplineValueEnumMap[
          reader.readStringOrNull(offsets[21])] ??
      JobModuleDiscipline.mechanical;
  object.displayOrder = reader.readLong(offsets[22]);
  object.draftNote = reader.readStringOrNull(offsets[23]);
  object.fieldDefinitionsJson = reader.readString(offsets[24]);
  object.firestoreId = reader.readStringOrNull(offsets[25]);
  object.functionalSection = reader.readStringOrNull(offsets[26]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[27]);
  object.isRequired = reader.readBool(offsets[28]);
  object.isSynced = reader.readBool(offsets[29]);
  object.jobExecutionFirestoreId = reader.readStringOrNull(offsets[30]);
  object.jobExecutionLocalId = reader.readLongOrNull(offsets[31]);
  object.laneActivationGeneration = reader.readLong(offsets[32]);
  object.laneKey = reader.readStringOrNull(offsets[33]);
  object.metadataJson = reader.readStringOrNull(offsets[34]);
  object.moduleCode = reader.readStringOrNull(offsets[35]);
  object.moduleDescription = reader.readStringOrNull(offsets[36]);
  object.moduleSnapshotJson = reader.readString(offsets[37]);
  object.moduleTitle = reader.readString(offsets[38]);
  object.notApplicableAt = reader.readDateTimeOrNull(offsets[39]);
  object.notApplicableByName = reader.readStringOrNull(offsets[40]);
  object.notApplicableByUid = reader.readStringOrNull(offsets[41]);
  object.notApplicableReason = reader.readStringOrNull(offsets[42]);
  object.operationalStatePreconditions =
      reader.readStringList(offsets[43]) ?? [];
  object.pairedEquipmentJson = reader.readStringOrNull(offsets[44]);
  object.pendingIssue = reader.readStringOrNull(offsets[45]);
  object.procedureRefs = reader.readStringList(offsets[46]) ?? [];
  object.reopenReason = reader.readStringOrNull(offsets[47]);
  object.reopenedAt = reader.readDateTimeOrNull(offsets[48]);
  object.reopenedByName = reader.readStringOrNull(offsets[49]);
  object.reopenedByUid = reader.readStringOrNull(offsets[50]);
  object.requiredForClosure = reader.readBool(offsets[51]);
  object.requiresFollowUp = reader.readBool(offsets[52]);
  object.responsesJson = reader.readString(offsets[53]);
  object.safetyClass = _JobModuleInstancesafetyClassValueEnumMap[
          reader.readStringOrNull(offsets[54])] ??
      JobModuleSafetyClass.normal;
  object.safetyConfirmations = reader.readStringList(offsets[55]) ?? [];
  object.status = _JobModuleInstancestatusValueEnumMap[
          reader.readStringOrNull(offsets[56])] ??
      JobModuleStatus.notStarted;
  object.submissionNote = reader.readStringOrNull(offsets[57]);
  object.submittedAt = reader.readDateTimeOrNull(offsets[58]);
  object.submittedByName = reader.readStringOrNull(offsets[59]);
  object.submittedByUid = reader.readStringOrNull(offsets[60]);
  object.subsystem = reader.readStringOrNull(offsets[61]);
  object.tags = reader.readStringList(offsets[62]) ?? [];
  object.targetRef = reader.readStringOrNull(offsets[63]);
  object.targetRefs = reader.readStringList(offsets[64]) ?? [];
  object.templateFirestoreId = reader.readStringOrNull(offsets[65]);
  object.templateModuleId = reader.readStringOrNull(offsets[66]);
  object.templateName = reader.readStringOrNull(offsets[67]);
  object.templatePackageId = reader.readStringOrNull(offsets[68]);
  object.templateVersionId = reader.readStringOrNull(offsets[69]);
  object.updatedAt = reader.readDateTime(offsets[70]);
  object.updatedByName = reader.readStringOrNull(offsets[71]);
  object.updatedByUid = reader.readStringOrNull(offsets[72]);
  object.useMode = _JobModuleInstanceuseModeValueEnumMap[
          reader.readStringOrNull(offsets[73])] ??
      JobModuleUseMode.scheduledPM;
  object.version = reader.readLong(offsets[74]);
  object.workflowLaneFirestoreId = reader.readStringOrNull(offsets[75]);
  return object;
}

P _jobModuleInstanceDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (_JobModuleInstanceassetTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetType.base) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readDateTime(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (_JobModuleInstancedisciplineValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobModuleDiscipline.mechanical) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    case 23:
      return (reader.readStringOrNull(offset)) as P;
    case 24:
      return (reader.readString(offset)) as P;
    case 25:
      return (reader.readStringOrNull(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    case 27:
      return (reader.readBool(offset)) as P;
    case 28:
      return (reader.readBool(offset)) as P;
    case 29:
      return (reader.readBool(offset)) as P;
    case 30:
      return (reader.readStringOrNull(offset)) as P;
    case 31:
      return (reader.readLongOrNull(offset)) as P;
    case 32:
      return (reader.readLong(offset)) as P;
    case 33:
      return (reader.readStringOrNull(offset)) as P;
    case 34:
      return (reader.readStringOrNull(offset)) as P;
    case 35:
      return (reader.readStringOrNull(offset)) as P;
    case 36:
      return (reader.readStringOrNull(offset)) as P;
    case 37:
      return (reader.readString(offset)) as P;
    case 38:
      return (reader.readString(offset)) as P;
    case 39:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 40:
      return (reader.readStringOrNull(offset)) as P;
    case 41:
      return (reader.readStringOrNull(offset)) as P;
    case 42:
      return (reader.readStringOrNull(offset)) as P;
    case 43:
      return (reader.readStringList(offset) ?? []) as P;
    case 44:
      return (reader.readStringOrNull(offset)) as P;
    case 45:
      return (reader.readStringOrNull(offset)) as P;
    case 46:
      return (reader.readStringList(offset) ?? []) as P;
    case 47:
      return (reader.readStringOrNull(offset)) as P;
    case 48:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 49:
      return (reader.readStringOrNull(offset)) as P;
    case 50:
      return (reader.readStringOrNull(offset)) as P;
    case 51:
      return (reader.readBool(offset)) as P;
    case 52:
      return (reader.readBool(offset)) as P;
    case 53:
      return (reader.readString(offset)) as P;
    case 54:
      return (_JobModuleInstancesafetyClassValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobModuleSafetyClass.normal) as P;
    case 55:
      return (reader.readStringList(offset) ?? []) as P;
    case 56:
      return (_JobModuleInstancestatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobModuleStatus.notStarted) as P;
    case 57:
      return (reader.readStringOrNull(offset)) as P;
    case 58:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 59:
      return (reader.readStringOrNull(offset)) as P;
    case 60:
      return (reader.readStringOrNull(offset)) as P;
    case 61:
      return (reader.readStringOrNull(offset)) as P;
    case 62:
      return (reader.readStringList(offset) ?? []) as P;
    case 63:
      return (reader.readStringOrNull(offset)) as P;
    case 64:
      return (reader.readStringList(offset) ?? []) as P;
    case 65:
      return (reader.readStringOrNull(offset)) as P;
    case 66:
      return (reader.readStringOrNull(offset)) as P;
    case 67:
      return (reader.readStringOrNull(offset)) as P;
    case 68:
      return (reader.readStringOrNull(offset)) as P;
    case 69:
      return (reader.readStringOrNull(offset)) as P;
    case 70:
      return (reader.readDateTime(offset)) as P;
    case 71:
      return (reader.readStringOrNull(offset)) as P;
    case 72:
      return (reader.readStringOrNull(offset)) as P;
    case 73:
      return (_JobModuleInstanceuseModeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          JobModuleUseMode.scheduledPM) as P;
    case 74:
      return (reader.readLong(offset)) as P;
    case 75:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _JobModuleInstanceassetTypeEnumValueMap = {
  r'base': r'base',
  r'furnace': r'furnace',
  r'forceCooler': r'forceCooler',
  r'innerCover': r'innerCover',
};
const _JobModuleInstanceassetTypeValueEnumMap = {
  r'base': AssetType.base,
  r'furnace': AssetType.furnace,
  r'forceCooler': AssetType.forceCooler,
  r'innerCover': AssetType.innerCover,
};
const _JobModuleInstancedisciplineEnumValueMap = {
  r'mechanical': r'mechanical',
  r'electrical': r'electrical',
  r'instrumentation': r'instrumentation',
  r'operations': r'operations',
  r'emd': r'emd',
  r'refractory': r'refractory',
  r'shiftInCharge': r'shiftInCharge',
  r'safety': r'safety',
  r'admin': r'admin',
  r'shared': r'shared',
  r'others': r'others',
};
const _JobModuleInstancedisciplineValueEnumMap = {
  r'mechanical': JobModuleDiscipline.mechanical,
  r'electrical': JobModuleDiscipline.electrical,
  r'instrumentation': JobModuleDiscipline.instrumentation,
  r'operations': JobModuleDiscipline.operations,
  r'emd': JobModuleDiscipline.emd,
  r'refractory': JobModuleDiscipline.refractory,
  r'shiftInCharge': JobModuleDiscipline.shiftInCharge,
  r'safety': JobModuleDiscipline.safety,
  r'admin': JobModuleDiscipline.admin,
  r'shared': JobModuleDiscipline.shared,
  r'others': JobModuleDiscipline.others,
};
const _JobModuleInstancesafetyClassEnumValueMap = {
  r'normal': r'normal',
  r'lotoRequired': r'lotoRequired',
  r'gasRisk': r'gasRisk',
  r'hotSurface': r'hotSurface',
  r'pressureTest': r'pressureTest',
  r'liftingRisk': r'liftingRisk',
  r'electricalPanel': r'electricalPanel',
  r'combustionSpecialist': r'combustionSpecialist',
  r'configurationControl': r'configurationControl',
};
const _JobModuleInstancesafetyClassValueEnumMap = {
  r'normal': JobModuleSafetyClass.normal,
  r'lotoRequired': JobModuleSafetyClass.lotoRequired,
  r'gasRisk': JobModuleSafetyClass.gasRisk,
  r'hotSurface': JobModuleSafetyClass.hotSurface,
  r'pressureTest': JobModuleSafetyClass.pressureTest,
  r'liftingRisk': JobModuleSafetyClass.liftingRisk,
  r'electricalPanel': JobModuleSafetyClass.electricalPanel,
  r'combustionSpecialist': JobModuleSafetyClass.combustionSpecialist,
  r'configurationControl': JobModuleSafetyClass.configurationControl,
};
const _JobModuleInstancestatusEnumValueMap = {
  r'notStarted': r'notStarted',
  r'inProgress': r'inProgress',
  r'draftSaved': r'draftSaved',
  r'submitted': r'submitted',
  r'accepted': r'accepted',
  r'reopened': r'reopened',
  r'notApplicable': r'notApplicable',
};
const _JobModuleInstancestatusValueEnumMap = {
  r'notStarted': JobModuleStatus.notStarted,
  r'inProgress': JobModuleStatus.inProgress,
  r'draftSaved': JobModuleStatus.draftSaved,
  r'submitted': JobModuleStatus.submitted,
  r'accepted': JobModuleStatus.accepted,
  r'reopened': JobModuleStatus.reopened,
  r'notApplicable': JobModuleStatus.notApplicable,
};
const _JobModuleInstanceuseModeEnumValueMap = {
  r'scheduledPM': r'scheduledPM',
  r'troubleshooting': r'troubleshooting',
  r'correctiveFollowUp': r'correctiveFollowUp',
  r'shutdownWork': r'shutdownWork',
  r'preStartVerification': r'preStartVerification',
  r'postRepairVerification': r'postRepairVerification',
  r'futurePackage': r'futurePackage',
  r'adHoc': r'adHoc',
};
const _JobModuleInstanceuseModeValueEnumMap = {
  r'scheduledPM': JobModuleUseMode.scheduledPM,
  r'troubleshooting': JobModuleUseMode.troubleshooting,
  r'correctiveFollowUp': JobModuleUseMode.correctiveFollowUp,
  r'shutdownWork': JobModuleUseMode.shutdownWork,
  r'preStartVerification': JobModuleUseMode.preStartVerification,
  r'postRepairVerification': JobModuleUseMode.postRepairVerification,
  r'futurePackage': JobModuleUseMode.futurePackage,
  r'adHoc': JobModuleUseMode.adHoc,
};

Id _jobModuleInstanceGetId(JobModuleInstance object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _jobModuleInstanceGetLinks(
    JobModuleInstance object) {
  return [];
}

void _jobModuleInstanceAttach(
    IsarCollection<dynamic> col, Id id, JobModuleInstance object) {
  object.id = id;
}

extension JobModuleInstanceQueryWhereSort
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QWhere> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'jobExecutionLocalId'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetNumber'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyIsRequired() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isRequired'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'requiredForClosure'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'addedDuringExecution'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhere>
      anyIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isDeleted'),
      );
    });
  }
}

extension JobModuleInstanceQueryWhere
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QWhereClause> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      firestoreIdEqualTo(String? firestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'firestoreId',
        value: [firestoreId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isSynced',
        value: [isSynced],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      jobExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      jobExecutionFirestoreIdEqualTo(String? jobExecutionFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionFirestoreId',
        value: [jobExecutionFirestoreId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      jobExecutionLocalIdEqualTo(int? jobExecutionLocalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'jobExecutionLocalId',
        value: [jobExecutionLocalId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      laneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'laneKey',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      laneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'laneKey',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      laneKeyEqualTo(String? laneKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'laneKey',
        value: [laneKey],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      laneKeyNotEqualTo(String? laneKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [],
              upper: [laneKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [laneKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [laneKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'laneKey',
              lower: [],
              upper: [laneKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateFirestoreId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'templateFirestoreId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateFirestoreIdEqualTo(String? templateFirestoreId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateFirestoreId',
        value: [templateFirestoreId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateFirestoreIdNotEqualTo(String? templateFirestoreId) {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templatePackageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templatePackageId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templatePackageIdEqualTo(String? templatePackageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templatePackageId',
        value: [templatePackageId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateVersionId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateVersionIdEqualTo(String? templateVersionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateVersionId',
        value: [templateVersionId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateModuleIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateModuleId',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateModuleIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'templateModuleId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateModuleIdEqualTo(String? templateModuleId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'templateModuleId',
        value: [templateModuleId],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      templateModuleIdNotEqualTo(String? templateModuleId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateModuleId',
              lower: [],
              upper: [templateModuleId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateModuleId',
              lower: [templateModuleId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateModuleId',
              lower: [templateModuleId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'templateModuleId',
              lower: [],
              upper: [templateModuleId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleCode',
        value: [null],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'moduleCode',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleCodeEqualTo(String? moduleCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleCode',
        value: [moduleCode],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleCodeNotEqualTo(String? moduleCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [],
              upper: [moduleCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [moduleCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [moduleCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [],
              upper: [moduleCode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      assetTypeEqualTo(AssetType assetType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetType',
        value: [assetType],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      assetNumberEqualTo(int assetNumber) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetNumber',
        value: [assetNumber],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleTitleEqualTo(String moduleTitle) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleTitle',
        value: [moduleTitle],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      moduleTitleNotEqualTo(String moduleTitle) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleTitle',
              lower: [],
              upper: [moduleTitle],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleTitle',
              lower: [moduleTitle],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleTitle',
              lower: [moduleTitle],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleTitle',
              lower: [],
              upper: [moduleTitle],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      statusEqualTo(JobModuleStatus status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'status',
        value: [status],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      statusNotEqualTo(JobModuleStatus status) {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      useModeEqualTo(JobModuleUseMode useMode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'useMode',
        value: [useMode],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      useModeNotEqualTo(JobModuleUseMode useMode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'useMode',
              lower: [],
              upper: [useMode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'useMode',
              lower: [useMode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'useMode',
              lower: [useMode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'useMode',
              lower: [],
              upper: [useMode],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      disciplineEqualTo(JobModuleDiscipline discipline) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'discipline',
        value: [discipline],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      disciplineNotEqualTo(JobModuleDiscipline discipline) {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      safetyClassEqualTo(JobModuleSafetyClass safetyClass) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'safetyClass',
        value: [safetyClass],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      safetyClassNotEqualTo(JobModuleSafetyClass safetyClass) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'safetyClass',
              lower: [],
              upper: [safetyClass],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'safetyClass',
              lower: [safetyClass],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'safetyClass',
              lower: [safetyClass],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'safetyClass',
              lower: [],
              upper: [safetyClass],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      isRequiredEqualTo(bool isRequired) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isRequired',
        value: [isRequired],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      isRequiredNotEqualTo(bool isRequired) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isRequired',
              lower: [],
              upper: [isRequired],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isRequired',
              lower: [isRequired],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isRequired',
              lower: [isRequired],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isRequired',
              lower: [],
              upper: [isRequired],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      requiredForClosureEqualTo(bool requiredForClosure) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'requiredForClosure',
        value: [requiredForClosure],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      requiredForClosureNotEqualTo(bool requiredForClosure) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requiredForClosure',
              lower: [],
              upper: [requiredForClosure],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requiredForClosure',
              lower: [requiredForClosure],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requiredForClosure',
              lower: [requiredForClosure],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'requiredForClosure',
              lower: [],
              upper: [requiredForClosure],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      addedDuringExecutionEqualTo(bool addedDuringExecution) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'addedDuringExecution',
        value: [addedDuringExecution],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      addedDuringExecutionNotEqualTo(bool addedDuringExecution) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedDuringExecution',
              lower: [],
              upper: [addedDuringExecution],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedDuringExecution',
              lower: [addedDuringExecution],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedDuringExecution',
              lower: [addedDuringExecution],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'addedDuringExecution',
              lower: [],
              upper: [addedDuringExecution],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'createdAt',
        value: [createdAt],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
      isDeletedEqualTo(bool isDeleted) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDeleted',
        value: [isDeleted],
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterWhereClause>
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

extension JobModuleInstanceQueryFilter
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QFilterCondition> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptanceNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptanceNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptanceNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acceptanceNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acceptanceNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptanceNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptanceNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acceptanceNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acceptedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acceptedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acceptedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'acceptedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'acceptedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acceptedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'acceptedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'acceptedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acceptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      acceptedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'acceptedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      actionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'actionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      actionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'actionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      actionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      actionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'actionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'addedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'addedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'addedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'addedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'addedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      addedDuringExecutionEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedDuringExecution',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      assetNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      assetTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      assetTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      assetTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      assetTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetType',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      chargeNoAtEventIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      chargeNoAtEventIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chargeNoAtEvent',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      chargeNoAtEventEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargeNoAtEvent',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'componentGroup',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'componentGroup',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'componentGroup',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'componentGroup',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      componentGroupIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'componentGroup',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      createdByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deleteReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deleteReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deleteReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deleteReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deleteReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deletedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deletedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      deletedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deletedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineEqualTo(
    JobModuleDiscipline value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineGreaterThan(
    JobModuleDiscipline value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineLessThan(
    JobModuleDiscipline value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineBetween(
    JobModuleDiscipline lower,
    JobModuleDiscipline upper, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'discipline',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'discipline',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      disciplineIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'discipline',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      displayOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      displayOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      displayOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      displayOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'draftNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'draftNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'draftNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'draftNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'draftNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'draftNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      draftNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'draftNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      fieldDefinitionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fieldDefinitionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      fieldDefinitionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fieldDefinitionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      fieldDefinitionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fieldDefinitionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      fieldDefinitionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fieldDefinitionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'firestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'firestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'firestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      firestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'firestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'functionalSection',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'functionalSection',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'functionalSection',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'functionalSection',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      functionalSectionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'functionalSection',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      isRequiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isRequired',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'jobExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'jobExecutionFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'jobExecutionFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionLocalIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionLocalIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'jobExecutionLocalId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      jobExecutionLocalIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'jobExecutionLocalId',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneActivationGenerationEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneActivationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneActivationGenerationGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneActivationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneActivationGenerationLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneActivationGeneration',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneActivationGenerationBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneActivationGeneration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'laneKey',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'laneKey',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'laneKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'laneKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'laneKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      laneKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'laneKey',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metadataJson',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadataJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadataJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      metadataJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadataJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'moduleCode',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'moduleCode',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleCode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'moduleDescription',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'moduleDescription',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleDescription',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleDescription',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleDescription',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleDescriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleDescription',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleSnapshotJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleSnapshotJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleSnapshotJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleSnapshotJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleSnapshotJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      moduleTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notApplicableAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notApplicableAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notApplicableAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notApplicableAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notApplicableAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notApplicableByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notApplicableByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notApplicableByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notApplicableByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notApplicableByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notApplicableByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notApplicableByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notApplicableByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notApplicableByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notApplicableByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notApplicableByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notApplicableByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notApplicableReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notApplicableReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notApplicableReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notApplicableReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notApplicableReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notApplicableReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      notApplicableReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notApplicableReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      operationalStatePreconditionsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      operationalStatePreconditionsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'operationalStatePreconditions',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pairedEquipmentJson',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pairedEquipmentJson',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pairedEquipmentJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pairedEquipmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pairedEquipmentJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pairedEquipmentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pairedEquipmentJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pairedEquipmentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pendingIssue',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pendingIssue',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pendingIssue',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pendingIssue',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pendingIssue',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      pendingIssueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pendingIssue',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      procedureRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'procedureRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      procedureRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'procedureRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      procedureRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      procedureRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'procedureRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenReason',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenReason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenReason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenReason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenReasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenReason',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reopenedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reopenedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reopenedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reopenedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reopenedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reopenedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      reopenedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reopenedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      requiredForClosureEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiredForClosure',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      requiresFollowUpEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requiresFollowUp',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      responsesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'responsesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      responsesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'responsesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      responsesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'responsesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      responsesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'responsesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassEqualTo(
    JobModuleSafetyClass value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassGreaterThan(
    JobModuleSafetyClass value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassLessThan(
    JobModuleSafetyClass value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassBetween(
    JobModuleSafetyClass lower,
    JobModuleSafetyClass upper, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyClass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyClass',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyClassIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyClass',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'safetyConfirmations',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'safetyConfirmations',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'safetyConfirmations',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'safetyConfirmations',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'safetyConfirmations',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      safetyConfirmationsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'safetyConfirmations',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusEqualTo(
    JobModuleStatus value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusGreaterThan(
    JobModuleStatus value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusLessThan(
    JobModuleStatus value, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusBetween(
    JobModuleStatus lower,
    JobModuleStatus upper, {
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'submissionNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'submissionNote',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'submissionNote',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'submissionNote',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'submissionNote',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submissionNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submissionNoteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'submissionNote',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'submittedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'submittedAt',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submittedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'submittedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'submittedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'submittedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'submittedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'submittedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'submittedByName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'submittedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'submittedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submittedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'submittedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'submittedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'submittedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'submittedByUid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'submittedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'submittedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'submittedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      submittedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'submittedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'subsystem',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'subsystem',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'subsystem',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      subsystemIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'subsystem',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'targetRef',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'targetRef',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRef',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRef',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRef',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetRefs',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetRefs',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      targetRefsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetRefs',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateModuleId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateModuleId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'templateModuleId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateModuleId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateModuleId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateModuleId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateModuleIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateModuleId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templatePackageId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templatePackageId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templatePackageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templatePackageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templatePackageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templatePackageId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'templateVersionId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'templateVersionId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'templateVersionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'templateVersionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'templateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      templateVersionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'templateVersionId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByName',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByName',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedByUid',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedByUid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedByUid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      updatedByUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedByUid',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeEqualTo(
    JobModuleUseMode value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeGreaterThan(
    JobModuleUseMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeLessThan(
    JobModuleUseMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeBetween(
    JobModuleUseMode lower,
    JobModuleUseMode upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'useMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'useMode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'useMode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'useMode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      useModeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'useMode',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
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

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'workflowLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'workflowLaneFirestoreId',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'workflowLaneFirestoreId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'workflowLaneFirestoreId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'workflowLaneFirestoreId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'workflowLaneFirestoreId',
        value: '',
      ));
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
      workflowLaneFirestoreIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'workflowLaneFirestoreId',
        value: '',
      ));
    });
  }
}

extension JobModuleInstanceQueryObject
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QFilterCondition> {}

extension JobModuleInstanceQueryLinks
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QFilterCondition> {}

extension JobModuleInstanceQuerySortBy
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QSortBy> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptanceNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptanceNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptanceNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptanceNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAcceptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAddedDuringExecutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDisplayOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDraftNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByDraftNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFieldDefinitionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFieldDefinitionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsRequired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRequired', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsRequiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRequired', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByLaneActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneActivationGeneration', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByLaneActivationGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneActivationGeneration', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleDescription', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleDescription', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleTitle', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByModuleTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleTitle', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByNotApplicableReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByPairedEquipmentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedEquipmentJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByPairedEquipmentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedEquipmentJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByPendingIssue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByPendingIssueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByReopenedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByRequiredForClosureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByRequiresFollowUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByResponsesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByResponsesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmissionNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmissionNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubmittedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTargetRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTargetRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateModuleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateModuleId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateModuleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateModuleId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUseMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useMode', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByUseModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useMode', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByWorkflowLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      sortByWorkflowLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowLaneFirestoreId', Sort.desc);
    });
  }
}

extension JobModuleInstanceQuerySortThenBy
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QSortThenBy> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptanceNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptanceNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptanceNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptanceNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAcceptedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByActionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByActionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'actionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAddedDuringExecutionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedDuringExecution', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAssetNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetNumber', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAssetType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByAssetTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetType', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByChargeNoAtEventDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargeNoAtEvent', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByComponentGroup() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByComponentGroupDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'componentGroup', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByCreatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeleteReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeleteReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deleteReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDeletedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDiscipline() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDisciplineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discipline', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDisplayOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayOrder', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDraftNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByDraftNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draftNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFieldDefinitionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFieldDefinitionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fieldDefinitionsJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'firestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFunctionalSection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByFunctionalSectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'functionalSection', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsRequired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRequired', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsRequiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRequired', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByJobExecutionFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByJobExecutionFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByJobExecutionLocalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jobExecutionLocalId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByLaneActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneActivationGeneration', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByLaneActivationGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneActivationGeneration', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByLaneKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByLaneKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'laneKey', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByMetadataJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByMetadataJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleDescription', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleDescription', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleSnapshotJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleSnapshotJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSnapshotJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleTitle', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByModuleTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleTitle', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByNotApplicableReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notApplicableReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByPairedEquipmentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedEquipmentJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByPairedEquipmentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedEquipmentJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByPendingIssue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByPendingIssueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pendingIssue', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenReason', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByReopenedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reopenedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByRequiredForClosureDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiredForClosure', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByRequiresFollowUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requiresFollowUp', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByResponsesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByResponsesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'responsesJson', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySafetyClass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySafetyClassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safetyClass', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmissionNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionNote', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmissionNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submissionNote', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubmittedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'submittedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubsystem() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenBySubsystemDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subsystem', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTargetRef() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTargetRefDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRef', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateFirestoreId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateModuleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateModuleId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateModuleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateModuleId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplatePackageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplatePackageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templatePackageId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByTemplateVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'templateVersionId', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByName', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUpdatedByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedByUid', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUseMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useMode', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByUseModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useMode', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByWorkflowLaneFirestoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowLaneFirestoreId', Sort.asc);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterSortBy>
      thenByWorkflowLaneFirestoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workflowLaneFirestoreId', Sort.desc);
    });
  }
}

extension JobModuleInstanceQueryWhereDistinct
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct> {
  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAcceptanceNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptanceNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAcceptedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAcceptedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByActionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'actionsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAddReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAddedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedByName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAddedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAddedDuringExecution() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedDuringExecution');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAssetNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetNumber');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByAssetType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByChargeNoAtEvent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByComponentGroup({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'componentGroup',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByCreatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByCreatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDeleteReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deleteReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDeletedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDeletedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDiscipline({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'discipline', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDisplayOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayOrder');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByDraftNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draftNote', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByFieldDefinitionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fieldDefinitionsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'firestoreId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByFunctionalSection({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'functionalSection',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByIsRequired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRequired');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByJobExecutionFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByJobExecutionLocalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByLaneActivationGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneActivationGeneration');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByLaneKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'laneKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByMetadataJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByModuleCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByModuleDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleDescription',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByModuleSnapshotJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleSnapshotJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByModuleTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByNotApplicableAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notApplicableAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByNotApplicableByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notApplicableByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByNotApplicableByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notApplicableByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByNotApplicableReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notApplicableReason',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByOperationalStatePreconditions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByPairedEquipmentJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pairedEquipmentJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByPendingIssue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pendingIssue', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByProcedureRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'procedureRefs');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByReopenReason({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenReason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByReopenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByReopenedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByReopenedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reopenedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByRequiredForClosure() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requiredForClosure');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByRequiresFollowUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requiresFollowUp');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByResponsesJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'responsesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySafetyClass({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyClass', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySafetyConfirmations() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'safetyConfirmations');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySubmissionNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'submissionNote',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySubmittedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'submittedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySubmittedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'submittedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySubmittedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'submittedByUid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctBySubsystem({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subsystem', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTargetRef({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRef', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTargetRefs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRefs');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTemplateFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateFirestoreId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTemplateModuleId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateModuleId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTemplateName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTemplatePackageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templatePackageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByTemplateVersionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'templateVersionId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByUpdatedByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByUpdatedByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedByUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByUseMode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useMode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QDistinct>
      distinctByWorkflowLaneFirestoreId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workflowLaneFirestoreId',
          caseSensitive: caseSensitive);
    });
  }
}

extension JobModuleInstanceQueryProperty
    on QueryBuilder<JobModuleInstance, JobModuleInstance, QQueryProperty> {
  QueryBuilder<JobModuleInstance, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      acceptanceNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptanceNote');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      acceptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      acceptedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      acceptedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, String, QQueryOperations>
      actionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'actionsJson');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      addReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addReason');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      addedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      addedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      addedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations>
      addedDuringExecutionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedDuringExecution');
    });
  }

  QueryBuilder<JobModuleInstance, int, QQueryOperations> assetNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetNumber');
    });
  }

  QueryBuilder<JobModuleInstance, AssetType, QQueryOperations>
      assetTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetType');
    });
  }

  QueryBuilder<JobModuleInstance, int?, QQueryOperations>
      chargeNoAtEventProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargeNoAtEvent');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      componentGroupProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'componentGroup');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      createdByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      createdByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdByUid');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      deleteReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deleteReason');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      deletedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      deletedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleDiscipline, QQueryOperations>
      disciplineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'discipline');
    });
  }

  QueryBuilder<JobModuleInstance, int, QQueryOperations>
      displayOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayOrder');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      draftNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draftNote');
    });
  }

  QueryBuilder<JobModuleInstance, String, QQueryOperations>
      fieldDefinitionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fieldDefinitionsJson');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      firestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'firestoreId');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      functionalSectionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'functionalSection');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations> isRequiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRequired');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      jobExecutionFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionFirestoreId');
    });
  }

  QueryBuilder<JobModuleInstance, int?, QQueryOperations>
      jobExecutionLocalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jobExecutionLocalId');
    });
  }

  QueryBuilder<JobModuleInstance, int, QQueryOperations>
      laneActivationGenerationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneActivationGeneration');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations> laneKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'laneKey');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      metadataJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataJson');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      moduleCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleCode');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      moduleDescriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleDescription');
    });
  }

  QueryBuilder<JobModuleInstance, String, QQueryOperations>
      moduleSnapshotJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleSnapshotJson');
    });
  }

  QueryBuilder<JobModuleInstance, String, QQueryOperations>
      moduleTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleTitle');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      notApplicableAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notApplicableAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      notApplicableByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notApplicableByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      notApplicableByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notApplicableByUid');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      notApplicableReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notApplicableReason');
    });
  }

  QueryBuilder<JobModuleInstance, List<String>, QQueryOperations>
      operationalStatePreconditionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationalStatePreconditions');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      pairedEquipmentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pairedEquipmentJson');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      pendingIssueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pendingIssue');
    });
  }

  QueryBuilder<JobModuleInstance, List<String>, QQueryOperations>
      procedureRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'procedureRefs');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      reopenReasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenReason');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      reopenedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      reopenedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      reopenedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reopenedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations>
      requiredForClosureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requiredForClosure');
    });
  }

  QueryBuilder<JobModuleInstance, bool, QQueryOperations>
      requiresFollowUpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requiresFollowUp');
    });
  }

  QueryBuilder<JobModuleInstance, String, QQueryOperations>
      responsesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'responsesJson');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleSafetyClass, QQueryOperations>
      safetyClassProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyClass');
    });
  }

  QueryBuilder<JobModuleInstance, List<String>, QQueryOperations>
      safetyConfirmationsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safetyConfirmations');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleStatus, QQueryOperations>
      statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      submissionNoteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'submissionNote');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime?, QQueryOperations>
      submittedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'submittedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      submittedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'submittedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      submittedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'submittedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      subsystemProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subsystem');
    });
  }

  QueryBuilder<JobModuleInstance, List<String>, QQueryOperations>
      tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      targetRefProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRef');
    });
  }

  QueryBuilder<JobModuleInstance, List<String>, QQueryOperations>
      targetRefsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRefs');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      templateFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateFirestoreId');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      templateModuleIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateModuleId');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      templateNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      templatePackageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templatePackageId');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      templateVersionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'templateVersionId');
    });
  }

  QueryBuilder<JobModuleInstance, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      updatedByNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByName');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      updatedByUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedByUid');
    });
  }

  QueryBuilder<JobModuleInstance, JobModuleUseMode, QQueryOperations>
      useModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useMode');
    });
  }

  QueryBuilder<JobModuleInstance, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }

  QueryBuilder<JobModuleInstance, String?, QQueryOperations>
      workflowLaneFirestoreIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workflowLaneFirestoreId');
    });
  }
}
