import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

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
  final suffix = detail == null ? '' : ' ($detail)';
  throw FormatException(
    'Invalid authority-critical workflow projection field "$field"$suffix: '
    '${value.runtimeType}',
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
  if (value == null) return null;
  if (value is! String) {
    return _projectionError(field, value, 'expected string');
  }
  final result = value.trim();
  return result.isEmpty ? null : result;
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

int _requiredInt(Map<String, dynamic> data, String field, {int minimum = 0}) {
  final value = data[field];
  if (value is! num || !value.isFinite || value.toInt() != value) {
    return _projectionError(field, value, 'required integer');
  }
  final result = value.toInt();
  if (result < minimum) {
    return _projectionError(field, value, 'minimum $minimum');
  }
  return result;
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
  final counterProposal =
      data['counterProposal'] is Map
          ? Map<String, dynamic>.from(data['counterProposal'] as Map)
          : null;
  final counterDecision =
      data['counterDecision'] is Map
          ? Map<String, dynamic>.from(data['counterDecision'] as Map)
          : null;
  final metadata = data['metadata'];

  return ComplianceRequestRecord()
    ..firestoreId = documentId
    ..isSynced = true
    ..version = _requiredInt(data, 'version', minimum: 1)
    ..title = _requiredString(data, 'title')
    ..description = _requiredString(data, 'description')
    ..originLaneKey = _string(data['originLaneKey'])
    ..targetLaneKey = _requiredString(data, 'targetLaneKey', allowed: _laneKeys)
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
    ..priorityKey = _requiredString(data, 'priorityKey', allowed: _priorityKeys)
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
    ..linkedExecutionFirestoreId = _string(data['linkedExecutionFirestoreId'])
    ..linkedLaneFirestoreId = _string(data['linkedLaneFirestoreId'])
    ..linkedModuleFirestoreId = _string(data['linkedModuleFirestoreId'])
    ..gatesLaneFirestoreId = _string(data['gatesLaneFirestoreId'])
    ..assetTypeKey = _requiredString(
      data,
      'assetTypeKey',
      allowed: _assetTypeKeys,
    )
    ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
    ..chargeNoAtEvent = (data['chargeNoAtEvent'] as num?)?.toInt()
    ..escalationTier = _optionalInt(data, 'escalationTier', fallback: 0)
    ..lastEscalatedAt = _optionalDate(data['lastEscalatedAt'])
    ..acknowledgementDueAt = _optionalDate(data['acknowledgementDueAt'])
    ..complianceDueAt = _optionalDate(data['complianceDueAt'])
    ..createdAt = _date(data['createdAt'], 'createdAt')
    ..updatedAt = _date(data['updatedAt'], 'updatedAt')
    ..isDeleted = data['isDeleted'] == true
    ..deletedAt = _optionalDate(data['deletedAt'])
    ..deletedByUid = _string(data['deletedByUid'])
    ..deletedByName = _string(data['deletedByName'])
    ..deleteReason = _string(data['deleteReason'])
    ..metadataJson = metadata == null ? null : jsonEncode(metadata);
}

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
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkflowAggregateRecord()
      ..firestoreId = doc.id
      ..jobExecutionFirestoreId = _requiredString(data, 'jobExecutionId')
      ..assetTypeKey = _requiredString(
        data,
        'assetTypeKey',
        allowed: _assetTypeKeys,
      )
      ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
      ..statusKey = _requiredString(
        data,
        'status',
        allowed: _workflowStatusKeys,
      )
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
      ..laneSetFinalizedByUid = _string(data['laneSetFinalizedByUid'])
      ..laneSetFinalizedByName = _string(data['laneSetFinalizedByName'])
      ..activeRedWork = data['activeRedWork'] == true
      ..awaitingPreparation = data['awaitingPreparation'] == true
      ..cancelled = data['cancelled'] == true
      ..completedAt = _optionalDate(data['completedAt'], 'completedAt')
      ..createdAt = _date(data['createdAt'], 'createdAt')
      ..updatedAt = _date(data['updatedAt'], 'updatedAt');
  }

  JobLaneRecord _lane(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return JobLaneRecord()
      ..firestoreId = doc.id
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
      ..acknowledgedByUid = _string(data['acknowledgedByUid'])
      ..acknowledgedByName = _string(data['acknowledgedByName'])
      ..acknowledgedAt = _optionalDate(data['acknowledgedAt'], 'acknowledgedAt')
      ..representedLaneKey = _string(data['representedLaneKey'])
      ..delegationBasis = _string(data['delegationBasis'])
      ..gatingComplianceRequestId = _string(data['gatingComplianceRequestId'])
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
  }

  ComplianceRequestRecord _compliance(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return complianceRequestRecordFromFirestoreData(
      documentId: doc.id,
      data: doc.data() ?? const <String, dynamic>{},
    );
  }

  EquipmentStatusRecord _equipment(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EquipmentStatusRecord()
      ..firestoreId = doc.id
      ..isSynced = true
      ..version = _requiredInt(data, 'version', minimum: 1)
      ..assetTypeKey = _requiredString(
        data,
        'assetTypeKey',
        allowed: _assetTypeKeys,
      )
      ..assetNumber = _requiredInt(data, 'assetNumber', minimum: 1)
      ..stateKey = _requiredString(data, 'state', allowed: _equipmentStateKeys)
      ..openMaintenanceCount = _requiredInt(
        data,
        'activeNonRedMaintenanceCount',
      )
      ..openRedCount = _requiredInt(data, 'activeRedWorkCount')
      ..awaitingPreparationCount = _requiredInt(
        data,
        'awaitingPreparationCount',
      )
      ..previousStateKey = _requiredString(
        data,
        'previousState',
        allowed: _equipmentStateKeys,
      )
      ..transitionTrigger = _string(data['transitionTrigger'])
      ..lastTransitionAt = _optionalDate(
        data['lastTransitionAt'],
        'lastTransitionAt',
      )
      ..lastTransitionByUid = _string(data['lastTransitionByUid'])
      ..lastTransitionByName = _string(data['lastTransitionByName'])
      ..updatedAt = _date(data['updatedAt'], 'updatedAt');
  }

  EquipmentPromptRecord _prompt(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EquipmentPromptRecord()
      ..firestoreId = doc.id
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
      ..question = _string(data['question'])
      ..appliesWhenLaneKey = _string(data['appliesWhenLaneKey'])
      ..complianceTargetLaneKey = _string(data['complianceTargetLaneKey'])
      ..complianceTitleTemplate = _string(data['complianceTitleTemplate'])
      ..successorTemplatePackageId = _string(data['successorTemplatePackageId'])
      ..successorTemplateVersionId = _string(data['successorTemplateVersionId'])
      ..successorTemplateContentHash = _string(
        data['successorTemplateContentHash'],
      )
      ..active = data['active'] != false
      ..createdAt = _date(data['createdAt'], 'createdAt')
      ..updatedAt = _date(data['updatedAt'], 'updatedAt');
  }

  WorkflowEventRecord _event(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WorkflowEventRecord()
      ..firestoreId = doc.id
      ..aggregateId = _requiredString(data, 'aggregateId')
      ..eventTypeKey = _requiredString(data, 'eventType')
      ..laneKey = _string(data['laneKey'])
      ..representedLaneKey = _string(data['representedLaneKey'])
      ..actorUid = _string(data['actorUid'])
      ..actorName = _string(data['actorName'])
      ..commandId = _string(data['commandId'])
      ..payloadJson = jsonEncode(data['payload'] ?? const <String, Object?>{})
      ..occurredAt = _date(data['occurredAt'], 'occurredAt')
      ..isSynced = true;
  }

  ComplianceAttemptRecord _attempt(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ComplianceAttemptRecord()
      ..firestoreId = doc.id
      ..complianceRequestFirestoreId = _requiredString(
        data,
        'complianceRequestId',
      )
      ..attemptNumber = _requiredInt(data, 'attemptNumber', minimum: 1)
      ..attemptedByUid = _requiredString(data, 'attemptedByUid')
      ..attemptedByName = _string(data['attemptedByName'])
      ..attemptedAt = _date(data['attemptedAt'], 'attemptedAt')
      ..note = _string(data['note']) ?? ''
      ..accepted = data['accepted'] == true
      ..acceptedByUid = _string(data['acceptedByUid'])
      ..acceptedByName = _string(data['acceptedByName'])
      ..acceptedAt = _optionalDate(data['acceptedAt'], 'acceptedAt')
      ..returnedByUid = _string(data['returnedByUid'])
      ..returnedByName = _string(data['returnedByName'])
      ..returnedAt = _optionalDate(data['returnedAt'], 'returnedAt')
      ..returnReason = _string(data['returnReason'])
      ..isSynced = true;
  }
}
