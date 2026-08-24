import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/validation/charge_number.dart';
import '../data/compliance_attempt_record.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_prompt_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_event_record.dart';

const Set<String> _assetTypeKeys = <String>{
  'base',
  'furnace',
  'forceCooler',
  'innerCover',
  'governedCustom',
};
const Set<String> _workflowStatusKeys = <String>{
  'pendingLaneClassification',
  'assigned',
  'partiallyAcknowledged',
  'fullyAcknowledged',
  'inProgress',
  'awaitingCompliance',
  'readyForClosure',
  'completed',
  'cancelled',
};
const Set<String> _laneKeys = <String>{
  'elec',
  'mech',
  'inst',
  'oprn',
  'emd',
  'red',
  'shared',
};
const Set<String> _laneStatusKeys = <String>{
  'pending',
  'acknowledged',
  'closed',
  'removed',
  'terminated',
};
const Set<String> _complianceStatusKeys = <String>{
  'raised',
  'acknowledged',
  'complied',
  'confirmedClosed',
  'superseded',
  'cancelled',
};
const Set<String> _conditionTypeKeys = <String>{
  'manual',
  'chargeComplete',
  'activityRef',
};
const Set<String> _requestPurposeKeys = <String>{
  'assurance',
  'deferment',
  'operationsSupport',
};
const Set<String> _defermentBasisKeys = <String>{
  'ongoingCycle',
  'equipmentRequired',
  'operationalCompliance',
  'safetyConstraint',
  'qualityConstraint',
  'other',
};
const Set<String> _operationsSupportTypeKeys = <String>{
  'craneMovement',
  'assetRelocation',
  'isolation',
  'processPreparation',
  'utilitySupport',
  'accessOrPermit',
  'other',
};
const Set<String> _operationsResourceKeys = <String>{
  'crane',
  'transferCar',
  'operationsCrew',
  'utilities',
  'other',
};
const Set<String> _priorityKeys = <String>{'low', 'medium', 'high', 'critical'};
const Set<String> _equipmentStateKeys = <String>{
  'available',
  'inService',
  'underMaintenance',
  'underRED',
  'awaitingPreparation',
};
const Set<String> _promptTypeKeys = <String>{'question', 'applicabilityMarker'};

Never _projectionError(String field, dynamic value, [String? detail]) {
  throw PersistedDataFormatException(
    field: field,
    source: 'workflow remote projection',
    detail: '${detail ?? 'invalid value'} (${value.runtimeType})',
  );
}

DateTime _date(dynamic value, [String field = 'date']) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return _projectionError(field, value, 'required timestamp');
}

String? _string(dynamic value, [String field = 'string']) {
  return readOptionalPersistedString(
    value,
    field: field,
    source: 'workflow remote projection',
  );
}

String _requiredString(
  Map<String, dynamic> data,
  String field, {
  Set<String>? allowed,
}) {
  final result = _string(data[field], field);
  if (result == null) {
    return _projectionError(field, data[field], 'required non-empty string');
  }
  if (allowed != null && !allowed.contains(result)) {
    return _projectionError(field, data[field], 'unsupported value');
  }
  return result;
}

String? _optionalAllowedString(
  Map<String, dynamic> data,
  String field,
  Set<String> allowed,
) {
  final value = _string(data[field], field);
  if (value != null && !allowed.contains(value)) {
    return _projectionError(field, data[field], 'unsupported value');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> data, String field, {int minimum = 0}) {
  return readRequiredPersistedInt(
    data[field],
    field: field,
    source: 'workflow remote projection',
    minimum: minimum,
  );
}

int _optionalInt(
  Map<String, dynamic> data,
  String field, {
  required int fallback,
  int minimum = 0,
}) {
  if (data[field] == null) return fallback;
  return _requiredInt(data, field, minimum: minimum);
}

bool _optionalBool(
  Map<String, dynamic> data,
  String field, {
  required bool fallback,
}) =>
    readOptionalPersistedBool(
      data[field],
      field: field,
      source: 'workflow remote projection',
    ) ??
    fallback;

Map<String, dynamic>? _optionalObject(
  Map<String, dynamic> data,
  String field,
) => readOptionalJsonObject(
  data[field],
  field: field,
  source: 'workflow remote projection',
);

DateTime? _optionalDate(dynamic value, [String field = 'date']) {
  if (value == null) return null;
  return _date(value, field);
}

class WorkflowRemoteFailure {
  final String collection;
  final String documentId;
  final String error;
  final DateTime? observedAt;

  const WorkflowRemoteFailure({
    required this.collection,
    required this.documentId,
    required this.error,
    required this.observedAt,
  });
}

class WorkflowRemoteBatch<T> {
  final List<T> records;
  final List<WorkflowRemoteFailure> failures;
  final List<DateTime> observedTimestamps;

  const WorkflowRemoteBatch({
    required this.records,
    required this.failures,
    required this.observedTimestamps,
  });
}

ComplianceRequestRecord complianceRequestRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) {
  final counterProposal = _optionalObject(data, 'counterProposal');
  final counterDecision = _optionalObject(data, 'counterDecision');
  final metadata = _optionalObject(data, 'metadata');
  final isDeleted = _optionalBool(data, 'isDeleted', fallback: false);

  final record =
      ComplianceRequestRecord()
        ..firestoreId = documentId
        ..isSynced = true
        ..version = _requiredInt(data, 'version', minimum: 1)
        ..title = _requiredString(data, 'title')
        ..description = _requiredString(data, 'description')
        ..originLaneKey = _string(data['originLaneKey'])
        ..targetLaneKey = _requiredString(
          data,
          'targetLaneKey',
          allowed: _laneKeys,
        )
        ..statusKey = _requiredString(
          data,
          'status',
          allowed: _complianceStatusKeys,
        )
        ..conditionTypeKey = _requiredString(
          data,
          'conditionTypeKey',
          allowed: _conditionTypeKeys,
        )
        ..conditionRef = _string(data['conditionRef'])
        ..requestPurposeKey =
            data['requestPurposeKey'] == null
                ? 'assurance'
                : _requiredString(
                  data,
                  'requestPurposeKey',
                  allowed: _requestPurposeKeys,
                )
        ..defermentBasisKey = _optionalAllowedString(
          data,
          'defermentBasisKey',
          _defermentBasisKeys,
        )
        ..operationsSupportTypeKey = _optionalAllowedString(
          data,
          'operationsSupportTypeKey',
          _operationsSupportTypeKeys,
        )
        ..operationsResourceKey = _optionalAllowedString(
          data,
          'operationsResourceKey',
          _operationsResourceKeys,
        )
        ..requestedLocation = _string(data['requestedLocation'])
        ..raisedUnderCoordination = _optionalBool(
          data,
          'raisedUnderCoordination',
          fallback: false,
        )
        ..coordinationBasis = _string(data['coordinationBasis'])
        ..priorityKey = _requiredString(
          data,
          'priorityKey',
          allowed: _priorityKeys,
        )
        ..raisedByUid = _string(data['raisedByUid'])
        ..raisedByName = _string(data['raisedByName'])
        ..raisedAt = _optionalDate(data['raisedAt'])
        ..acknowledgedByUid = _string(data['acknowledgedByUid'])
        ..acknowledgedByName = _string(data['acknowledgedByName'])
        ..acknowledgedAt = _optionalDate(data['acknowledgedAt'])
        ..compliedByUid = _string(data['compliedByUid'])
        ..compliedByName = _string(data['compliedByName'])
        ..compliedAt = _optionalDate(data['compliedAt'])
        ..complianceNote = _string(data['complianceNote'])
        ..currentAttemptId = _string(data['currentAttemptId'])
        ..attemptCount = _optionalInt(data, 'attemptCount', fallback: 0)
        ..confirmedByUid = _string(data['confirmedByUid'])
        ..confirmedByName = _string(data['confirmedByName'])
        ..confirmedAt = _optionalDate(data['confirmedAt'])
        ..confirmNote = _string(data['confirmNote'])
        ..becameDueAt = _optionalDate(data['becameDueAt'])
        ..dueMarkedByUid = _string(data['dueMarkedByUid'])
        ..dueMarkedByName = _string(data['dueMarkedByName'])
        ..dueMarkedAt = _optionalDate(data['dueMarkedAt'])
        ..counterDepth = _optionalInt(data, 'counterDepth', fallback: 0)
        ..counterConditionOfId = _string(data['counterConditionOfId'])
        ..supersededById = _string(data['supersededById'])
        ..counterProposedByUid = _string(counterProposal?['proposedByUid'])
        ..counterProposedByName = _string(counterProposal?['proposedByName'])
        ..counterProposedAt = _optionalDate(counterProposal?['proposedAt'])
        ..counterRevisedDescription = _string(
          counterProposal?['revisedDescription'],
        )
        ..counterDecisionByUid = _string(counterDecision?['decidedByUid'])
        ..counterDecisionByName = _string(counterDecision?['decidedByName'])
        ..counterDecisionAt = _optionalDate(counterDecision?['decidedAt'])
        ..counterDecisionNote = _string(counterDecision?['note'])
        ..correctionCount = _optionalInt(data, 'correctionCount', fallback: 0)
        ..lastCorrectionByUid = _string(data['lastCorrectionByUid'])
        ..lastCorrectionByName = _string(data['lastCorrectionByName'])
        ..lastCorrectionAt = _optionalDate(data['lastCorrectionAt'])
        ..lastCorrectionReason = _string(data['lastCorrectionReason'])
        ..linkedWorkflowId = _requiredString(data, 'linkedWorkflowId')
        ..linkedMaintenanceFirestoreId = _string(
          data['linkedMaintenanceFirestoreId'],
        )
        ..linkedExecutionFirestoreId = _string(
          data['linkedExecutionFirestoreId'],
        )
        ..linkedLaneFirestoreId = _string(data['linkedLaneFirestoreId'])
        ..linkedModuleFirestoreId = _string(data['linkedModuleFirestoreId'])
        ..gatesLaneFirestoreId = _string(data['gatesLaneFirestoreId'])
        ..assetTypeKey = _requiredString(
          data,
          'assetTypeKey',
          allowed: _assetTypeKeys,
        )
        ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
        ..chargeNoAtEvent = readOptionalPersistedChargeNumber(
          data['chargeNoAtEvent'],
          field: 'chargeNoAtEvent',
          source: 'workflow remote projection',
        )
        ..escalationTier = _optionalInt(data, 'escalationTier', fallback: 0)
        ..lastEscalatedAt = _optionalDate(data['lastEscalatedAt'])
        ..acknowledgementDueAt = _optionalDate(data['acknowledgementDueAt'])
        ..complianceDueAt = _optionalDate(data['complianceDueAt'])
        ..createdAt = _date(data['createdAt'], 'createdAt')
        ..updatedAt = _date(data['updatedAt'], 'updatedAt')
        ..isDeleted = isDeleted
        ..deletedAt = _optionalDate(data['deletedAt'])
        ..deletedByUid = _string(data['deletedByUid'])
        ..deletedByName = _string(data['deletedByName'])
        ..deleteReason = _string(data['deleteReason'])
        ..metadataJson = metadata == null ? null : jsonEncode(metadata);

  if (record.isDeleted != (record.deletedAt != null)) {
    return _projectionError(
      'deletedAt',
      data['deletedAt'],
      'deletion flag and timestamp must be present together',
    );
  }
  if (!record.isDeleted &&
      (record.deletedByUid != null ||
          record.deletedByName != null ||
          record.deleteReason != null)) {
    return _projectionError(
      'isDeleted',
      data['isDeleted'],
      'active compliance records cannot carry deletion state',
    );
  }
  if (record.updatedAt.isBefore(record.createdAt)) {
    return _projectionError(
      'updatedAt',
      data['updatedAt'],
      'cannot precede createdAt',
    );
  }
  if (record.raisedUnderCoordination != (record.coordinationBasis != null)) {
    return _projectionError(
      'coordinationBasis',
      data['coordinationBasis'],
      'coordination marker and basis must be present together',
    );
  }
  if (record.raisedUnderCoordination &&
      record.coordinationBasis != 'supervisory-workflow-coordination') {
    return _projectionError(
      'coordinationBasis',
      data['coordinationBasis'],
      'must use the canonical supervisory coordination basis',
    );
  }
  if (record.requestPurposeKey == 'deferment') {
    if (record.targetLaneKey != 'oprn' ||
        record.conditionTypeKey == 'manual' ||
        record.defermentBasisKey == null ||
        record.linkedMaintenanceFirestoreId == null) {
      return _projectionError(
        'requestPurposeKey',
        data['requestPurposeKey'],
        'deferment requires a basis, release condition and maintenance link',
      );
    }
  } else if (record.defermentBasisKey != null) {
    return _projectionError(
      'defermentBasisKey',
      data['defermentBasisKey'],
      'is valid only for deferment',
    );
  }
  if (record.requestPurposeKey == 'operationsSupport') {
    if (record.targetLaneKey != 'oprn' ||
        record.operationsSupportTypeKey == null ||
        record.operationsResourceKey == null ||
        (<String>{
              'craneMovement',
              'assetRelocation',
            }.contains(record.operationsSupportTypeKey) &&
            record.requestedLocation == null)) {
      return _projectionError(
        'requestPurposeKey',
        data['requestPurposeKey'],
        'Operations support requires Operations, support type and resource',
      );
    }
  } else if (record.operationsSupportTypeKey != null ||
      record.operationsResourceKey != null ||
      record.requestedLocation != null) {
    return _projectionError(
      'operationsSupportTypeKey',
      data['operationsSupportTypeKey'],
      'support details are valid only for Operations support',
    );
  }
  return record;
}

WorkflowAggregateRecord workflowAggregateRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) {
  final assetTypeKey = _requiredString(
    data,
    'assetTypeKey',
    allowed: _assetTypeKeys,
  );
  final custom = assetTypeKey == 'governedCustom';
  final assetClassId =
      custom
          ? _requiredString(data, 'assetClassId')
          : _string(data['assetClassId'], 'assetClassId');
  final assetInstanceId =
      custom
          ? _requiredString(data, 'assetInstanceId')
          : _string(data['assetInstanceId'], 'assetInstanceId');
  return WorkflowAggregateRecord()
    ..firestoreId = documentId
    ..jobExecutionFirestoreId = _requiredString(data, 'jobExecutionId')
    ..assetTypeKey = assetTypeKey
    ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
    ..assetClassId = assetClassId
    ..assetInstanceId = assetInstanceId
    ..statusKey = _requiredString(data, 'status', allowed: _workflowStatusKeys)
    ..workflowSchemaVersion = _requiredInt(
      data,
      'workflowSchemaVersion',
      minimum: 1,
    )
    ..version = _requiredInt(data, 'version')
    ..laneSetVersion = _requiredInt(data, 'laneSetVersion')
    ..laneSetFinalizedAt = _optionalDate(
      data['laneSetFinalizedAt'],
      'laneSetFinalizedAt',
    )
    ..laneSetFinalizedByUid = _string(
      data['laneSetFinalizedByUid'],
      'laneSetFinalizedByUid',
    )
    ..laneSetFinalizedByName = _string(
      data['laneSetFinalizedByName'],
      'laneSetFinalizedByName',
    )
    ..activeRedWork = _optionalBool(data, 'activeRedWork', fallback: false)
    ..awaitingPreparation = _optionalBool(
      data,
      'awaitingPreparation',
      fallback: false,
    )
    ..cancelled = _optionalBool(data, 'cancelled', fallback: false)
    ..completedAt = _optionalDate(data['completedAt'], 'completedAt')
    ..createdAt = _date(data['createdAt'], 'createdAt')
    ..updatedAt = _date(data['updatedAt'], 'updatedAt');
}

JobLaneRecord jobLaneRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) =>
    JobLaneRecord()
      ..firestoreId = documentId
      ..workflowFirestoreId = _requiredString(data, 'workflowId')
      ..jobExecutionFirestoreId = _requiredString(data, 'jobExecutionId')
      ..laneKey = _requiredString(data, 'laneKey', allowed: _laneKeys)
      ..statusKey = _requiredString(data, 'status', allowed: _laneStatusKeys)
      ..activationGeneration = _requiredInt(
        data,
        'activationGeneration',
        minimum: 1,
      )
      ..version = _requiredInt(data, 'version', minimum: 1)
      ..progressRevision = _optionalInt(data, 'progressRevision', fallback: 0)
      ..isSynced = true
      ..acknowledgedByUid = _string(
        data['acknowledgedByUid'],
        'acknowledgedByUid',
      )
      ..acknowledgedByName = _string(
        data['acknowledgedByName'],
        'acknowledgedByName',
      )
      ..acknowledgedAt = _optionalDate(data['acknowledgedAt'], 'acknowledgedAt')
      ..representedLaneKey = _string(
        data['representedLaneKey'],
        'representedLaneKey',
      )
      ..delegationBasis = _string(data['delegationBasis'], 'delegationBasis')
      ..gatingComplianceRequestId = _string(
        data['gatingComplianceRequestId'],
        'gatingComplianceRequestId',
      )
      ..assetTypeKey = _requiredString(
        data,
        'assetTypeKey',
        allowed: _assetTypeKeys,
      )
      ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
      ..displayOrder = _optionalInt(data, 'displayOrder', fallback: 0)
      ..acknowledgementDueAt = _optionalDate(
        data['acknowledgementDueAt'],
        'acknowledgementDueAt',
      )
      ..createdAt = _date(data['createdAt'], 'createdAt')
      ..updatedAt = _date(data['updatedAt'], 'updatedAt');

EquipmentStatusRecord equipmentStatusRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) {
  final assetTypeKey = _requiredString(
    data,
    'assetTypeKey',
    allowed: _assetTypeKeys,
  );
  final custom = assetTypeKey == 'governedCustom';
  final assetClassId =
      custom
          ? _requiredString(data, 'assetClassId')
          : _string(data['assetClassId'], 'assetClassId');
  final assetInstanceId =
      custom
          ? _requiredString(data, 'assetInstanceId')
          : _string(data['assetInstanceId'], 'assetInstanceId');
  if (custom &&
      documentId != 'governedCustom_${assetClassId}_$assetInstanceId') {
    return _projectionError(
      'documentId',
      documentId,
      'must match governed custom class and asset instance identity',
    );
  }
  return EquipmentStatusRecord()
    ..firestoreId = documentId
    ..isSynced = true
    ..version = _requiredInt(data, 'version', minimum: 1)
    ..assetTypeKey = assetTypeKey
    ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
    ..assetClassId = assetClassId
    ..assetInstanceId = assetInstanceId
    ..stateKey = _requiredString(data, 'state', allowed: _equipmentStateKeys)
    ..openMaintenanceCount = _requiredInt(data, 'activeNonRedMaintenanceCount')
    ..openRedCount = _requiredInt(data, 'activeRedWorkCount')
    ..awaitingPreparationCount = _requiredInt(data, 'awaitingPreparationCount')
    ..previousStateKey = _requiredString(
      data,
      'previousState',
      allowed: _equipmentStateKeys,
    )
    ..transitionTrigger = _string(
      data['transitionTrigger'],
      'transitionTrigger',
    )
    ..lastTransitionAt = _optionalDate(
      data['lastTransitionAt'],
      'lastTransitionAt',
    )
    ..lastTransitionByUid = _string(
      data['lastTransitionByUid'],
      'lastTransitionByUid',
    )
    ..lastTransitionByName = _string(
      data['lastTransitionByName'],
      'lastTransitionByName',
    )
    ..updatedAt = _date(data['updatedAt'], 'updatedAt');
}

EquipmentPromptRecord equipmentPromptRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) =>
    EquipmentPromptRecord()
      ..firestoreId = documentId
      ..isSynced = true
      ..version = _requiredInt(data, 'version', minimum: 1)
      ..assetTypeKey = _requiredString(
        data,
        'assetTypeKey',
        allowed: _assetTypeKeys,
      )
      ..promptKey = _requiredString(data, 'promptKey')
      ..promptTypeKey = _requiredString(
        data,
        'promptTypeKey',
        allowed: _promptTypeKeys,
      )
      ..question = _string(data['question'], 'question')
      ..appliesWhenLaneKey = _string(
        data['appliesWhenLaneKey'],
        'appliesWhenLaneKey',
      )
      ..complianceTargetLaneKey = _string(
        data['complianceTargetLaneKey'],
        'complianceTargetLaneKey',
      )
      ..complianceTitleTemplate = _string(
        data['complianceTitleTemplate'],
        'complianceTitleTemplate',
      )
      ..successorTemplatePackageId = _string(
        data['successorTemplatePackageId'],
        'successorTemplatePackageId',
      )
      ..successorTemplateVersionId = _string(
        data['successorTemplateVersionId'],
        'successorTemplateVersionId',
      )
      ..successorTemplateContentHash = _string(
        data['successorTemplateContentHash'],
        'successorTemplateContentHash',
      )
      ..active = _optionalBool(data, 'active', fallback: true)
      ..createdAt = _date(data['createdAt'], 'createdAt')
      ..updatedAt = _date(data['updatedAt'], 'updatedAt');

WorkflowEventRecord workflowEventRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) {
  final payload = _optionalObject(data, 'payload') ?? const <String, dynamic>{};
  return WorkflowEventRecord()
    ..firestoreId = documentId
    ..aggregateId = _requiredString(data, 'aggregateId')
    ..eventTypeKey = _requiredString(data, 'eventType')
    ..laneKey = _string(data['laneKey'], 'laneKey')
    ..representedLaneKey = _string(
      data['representedLaneKey'],
      'representedLaneKey',
    )
    ..actorUid = _string(data['actorUid'], 'actorUid')
    ..actorName = _string(data['actorName'], 'actorName')
    ..commandId = _string(data['commandId'], 'commandId')
    ..payloadJson = jsonEncode(payload)
    ..occurredAt = _date(data['occurredAt'], 'occurredAt')
    ..isSynced = true;
}

ComplianceAttemptRecord complianceAttemptRecordFromFirestoreData({
  required String documentId,
  required Map<String, dynamic> data,
}) =>
    ComplianceAttemptRecord()
      ..firestoreId = documentId
      ..complianceRequestFirestoreId = _requiredString(
        data,
        'complianceRequestId',
      )
      ..attemptNumber = _requiredInt(data, 'attemptNumber', minimum: 1)
      ..attemptedByUid = _requiredString(data, 'attemptedByUid')
      ..attemptedByName = _string(data['attemptedByName'], 'attemptedByName')
      ..attemptedAt = _date(data['attemptedAt'], 'attemptedAt')
      ..note = _requiredString(data, 'note')
      ..accepted = readRequiredPersistedBool(
        data['accepted'],
        field: 'accepted',
        source: 'workflow remote projection',
      )
      ..acceptedByUid = _string(data['acceptedByUid'], 'acceptedByUid')
      ..acceptedByName = _string(data['acceptedByName'], 'acceptedByName')
      ..acceptedAt = _optionalDate(data['acceptedAt'], 'acceptedAt')
      ..returnedByUid = _string(data['returnedByUid'], 'returnedByUid')
      ..returnedByName = _string(data['returnedByName'], 'returnedByName')
      ..returnedAt = _optionalDate(data['returnedAt'], 'returnedAt')
      ..returnReason = _string(data['returnReason'], 'returnReason')
      ..isSynced = true;

abstract interface class WorkflowRemoteReadRepository {
  Future<WorkflowRemoteBatch<WorkflowAggregateRecord>>
  fetchWorkflowsUpdatedSince(DateTime? since);
  Future<WorkflowRemoteBatch<JobLaneRecord>> fetchLanesUpdatedSince(
    DateTime? since,
  );
  Future<WorkflowRemoteBatch<ComplianceRequestRecord>>
  fetchComplianceUpdatedSince(DateTime? since);
  Future<WorkflowRemoteBatch<EquipmentStatusRecord>> fetchEquipmentUpdatedSince(
    DateTime? since,
  );
  Future<WorkflowRemoteBatch<EquipmentPromptRecord>> fetchPromptsUpdatedSince(
    DateTime? since,
  );
  Future<WorkflowRemoteBatch<WorkflowEventRecord>> fetchEventsAfter(
    DateTime? since,
  );
  Future<WorkflowRemoteBatch<ComplianceAttemptRecord>> fetchAttemptsAfter(
    DateTime? since,
  );
}

class FirestoreWorkflowReadRepository implements WorkflowRemoteReadRepository {
  static const int _pageSize = 250;
  final FirebaseFirestore firestore;
  const FirestoreWorkflowReadRepository(this.firestore);

  Future<WorkflowRemoteBatch<T>> _fetchAll<T>({
    required String collection,
    required String timestampField,
    required DateTime? since,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) map,
  }) async {
    // Re-read the boundary millisecond. Upserts are idempotent and this avoids
    // losing a document whose server timestamp equals the previous watermark.
    final lowerBound = since?.subtract(const Duration(milliseconds: 1));
    Query<Map<String, dynamic>> base = firestore.collection(collection);
    if (lowerBound != null) {
      base = base.where(
        timestampField,
        isGreaterThanOrEqualTo: Timestamp.fromDate(lowerBound),
      );
    }
    base = base.orderBy(timestampField).orderBy(FieldPath.documentId);

    final records = <T>[];
    final failures = <WorkflowRemoteFailure>[];
    final observedTimestamps = <DateTime>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var pageQuery = base.limit(_pageSize);
      if (cursor != null) pageQuery = pageQuery.startAfterDocument(cursor);
      final page = await pageQuery.get();
      for (final document in page.docs) {
        DateTime? observedAt;
        try {
          observedAt = _optionalDate(
            document.data()[timestampField],
            timestampField,
          );
          if (observedAt != null) observedTimestamps.add(observedAt);
          records.add(map(document));
        } catch (error) {
          failures.add(
            WorkflowRemoteFailure(
              collection: collection,
              documentId: document.id,
              error: '$error',
              observedAt: observedAt,
            ),
          );
        }
      }
      if (page.docs.length < _pageSize) break;
      cursor = page.docs.last;
    }
    return WorkflowRemoteBatch<T>(
      records: List<T>.unmodifiable(records),
      failures: List<WorkflowRemoteFailure>.unmodifiable(failures),
      observedTimestamps: List<DateTime>.unmodifiable(observedTimestamps),
    );
  }

  @override
  Future<WorkflowRemoteBatch<WorkflowAggregateRecord>>
  fetchWorkflowsUpdatedSince(DateTime? since) => _fetchAll(
    collection: 'maintenance_workflows',
    timestampField: 'updatedAt',
    since: since,
    map: _workflow,
  );

  @override
  Future<WorkflowRemoteBatch<JobLaneRecord>> fetchLanesUpdatedSince(
    DateTime? since,
  ) => _fetchAll(
    collection: 'job_lanes',
    timestampField: 'updatedAt',
    since: since,
    map: _lane,
  );

  @override
  Future<WorkflowRemoteBatch<ComplianceRequestRecord>>
  fetchComplianceUpdatedSince(DateTime? since) => _fetchAll(
    collection: 'compliance_requests',
    timestampField: 'updatedAt',
    since: since,
    map: _compliance,
  );

  Future<ComplianceRequestRecord?> fetchComplianceById(
    String complianceId,
  ) async {
    final id = complianceId.trim();
    if (id.isEmpty) return null;
    final document = await firestore
        .collection('compliance_requests')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!document.exists) return null;
    return _compliance(document);
  }

  @override
  Future<WorkflowRemoteBatch<EquipmentStatusRecord>> fetchEquipmentUpdatedSince(
    DateTime? since,
  ) => _fetchAll(
    collection: 'equipment_status',
    timestampField: 'updatedAt',
    since: since,
    map: _equipment,
  );

  @override
  Future<WorkflowRemoteBatch<EquipmentPromptRecord>> fetchPromptsUpdatedSince(
    DateTime? since,
  ) => _fetchAll(
    collection: 'equipment_prompt_master',
    timestampField: 'updatedAt',
    since: since,
    map: _prompt,
  );

  @override
  Future<WorkflowRemoteBatch<WorkflowEventRecord>> fetchEventsAfter(
    DateTime? since,
  ) => _fetchAll(
    collection: 'maintenance_workflow_events',
    timestampField: 'occurredAt',
    since: since,
    map: _event,
  );

  @override
  Future<WorkflowRemoteBatch<ComplianceAttemptRecord>> fetchAttemptsAfter(
    DateTime? since,
  ) => _fetchAll(
    collection: 'compliance_attempts',
    timestampField: 'attemptedAt',
    since: since,
    map: _attempt,
  );

  WorkflowAggregateRecord _workflow(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => workflowAggregateRecordFromFirestoreData(
    documentId: doc.id,
    data: doc.data() ?? const <String, dynamic>{},
  );

  JobLaneRecord _lane(DocumentSnapshot<Map<String, dynamic>> doc) =>
      jobLaneRecordFromFirestoreData(
        documentId: doc.id,
        data: doc.data() ?? const <String, dynamic>{},
      );

  ComplianceRequestRecord _compliance(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return complianceRequestRecordFromFirestoreData(
      documentId: doc.id,
      data: doc.data() ?? const <String, dynamic>{},
    );
  }

  EquipmentStatusRecord _equipment(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => equipmentStatusRecordFromFirestoreData(
    documentId: doc.id,
    data: doc.data() ?? const <String, dynamic>{},
  );

  EquipmentPromptRecord _prompt(DocumentSnapshot<Map<String, dynamic>> doc) =>
      equipmentPromptRecordFromFirestoreData(
        documentId: doc.id,
        data: doc.data() ?? const <String, dynamic>{},
      );

  WorkflowEventRecord _event(DocumentSnapshot<Map<String, dynamic>> doc) =>
      workflowEventRecordFromFirestoreData(
        documentId: doc.id,
        data: doc.data() ?? const <String, dynamic>{},
      );

  ComplianceAttemptRecord _attempt(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => complianceAttemptRecordFromFirestoreData(
    documentId: doc.id,
    data: doc.data() ?? const <String, dynamic>{},
  );
}
