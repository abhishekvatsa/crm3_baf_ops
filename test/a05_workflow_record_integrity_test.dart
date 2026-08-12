import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 workflow persisted record integrity', () {
    test('all supported workflow record families decode current records', () {
      expect(
        workflowAggregateRecordFromFirestoreData(
          documentId: 'workflow-1',
          data: _workflow(),
        ).cancelled,
        isFalse,
      );
      expect(
        jobLaneRecordFromFirestoreData(
          documentId: 'lane-1',
          data: _lane(),
        ).progressRevision,
        0,
      );
      expect(
        equipmentStatusRecordFromFirestoreData(
          documentId: 'furnace-7',
          data: _equipment(),
        ).openRedCount,
        0,
      );
      expect(
        equipmentPromptRecordFromFirestoreData(
          documentId: 'prompt-1',
          data: _prompt(),
        ).active,
        isTrue,
      );
      expect(
        workflowEventRecordFromFirestoreData(
          documentId: 'event-1',
          data: _event(),
        ).payloadJson,
        '{}',
      );
      expect(
        complianceAttemptRecordFromFirestoreData(
          documentId: 'attempt-1',
          data: _attempt(),
        ).note,
        'Condition confirmed',
      );
    });

    test('wrong-typed present booleans fail instead of becoming defaults', () {
      _expectFormat(
        () => workflowAggregateRecordFromFirestoreData(
          documentId: 'workflow-1',
          data: _workflow()..['cancelled'] = 0,
        ),
      );
      _expectFormat(
        () => equipmentPromptRecordFromFirestoreData(
          documentId: 'prompt-1',
          data: _prompt()..['active'] = 'yes',
        ),
      );
      _expectFormat(
        () => complianceAttemptRecordFromFirestoreData(
          documentId: 'attempt-1',
          data: _attempt()..['accepted'] = 1,
        ),
      );
    });

    test('fractional and string counters fail instead of being coerced', () {
      _expectFormat(
        () => jobLaneRecordFromFirestoreData(
          documentId: 'lane-1',
          data: _lane()..['progressRevision'] = 1.0,
        ),
      );
      _expectFormat(
        () => equipmentStatusRecordFromFirestoreData(
          documentId: 'furnace-7',
          data: _equipment()..['activeRedWorkCount'] = '0',
        ),
      );
      _expectFormat(
        () => complianceRequestRecordFromFirestoreData(
          documentId: 'compliance-1',
          data: _compliance()..['chargeNoAtEvent'] = 42.0,
        ),
      );
    });

    test('malformed present objects and required text fail closed', () {
      _expectFormat(
        () => workflowEventRecordFromFirestoreData(
          documentId: 'event-1',
          data: _event()..['payload'] = <Object>[],
        ),
      );
      _expectFormat(
        () => complianceRequestRecordFromFirestoreData(
          documentId: 'compliance-1',
          data: _compliance()..['counterProposal'] = 'not-an-object',
        ),
      );
      _expectFormat(
        () => complianceAttemptRecordFromFirestoreData(
          documentId: 'attempt-1',
          data: _attempt()..['note'] = null,
        ),
      );
    });

    test('compliance deletion and timeline contradictions fail closed', () {
      _expectFormat(
        () => complianceRequestRecordFromFirestoreData(
          documentId: 'compliance-1',
          data: _compliance()..['deletedAt'] = _later,
        ),
      );
      _expectFormat(
        () => complianceRequestRecordFromFirestoreData(
          documentId: 'compliance-1',
          data: _compliance()..['updatedAt'] = '2026-08-11T09:00:00Z',
        ),
      );
    });

    test('documented absent legacy workflow values remain compatible', () {
      final workflow =
          _workflow()
            ..remove('activeRedWork')
            ..remove('awaitingPreparation')
            ..remove('cancelled');
      final lane =
          _lane()
            ..remove('progressRevision')
            ..remove('displayOrder');
      final prompt = _prompt()..remove('active');

      expect(
        workflowAggregateRecordFromFirestoreData(
          documentId: 'workflow-1',
          data: workflow,
        ).activeRedWork,
        isFalse,
      );
      expect(
        jobLaneRecordFromFirestoreData(
          documentId: 'lane-1',
          data: lane,
        ).displayOrder,
        0,
      );
      expect(
        equipmentPromptRecordFromFirestoreData(
          documentId: 'prompt-1',
          data: prompt,
        ).active,
        isTrue,
      );
    });
  });
}

void _expectFormat(void Function() decode) {
  expect(decode, throwsA(isA<PersistedDataFormatException>()));
}

const _created = '2026-08-12T08:00:00Z';
const _later = '2026-08-12T09:00:00Z';

Map<String, dynamic> _workflow() => <String, dynamic>{
  'jobExecutionId': 'execution-1',
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'status': 'assigned',
  'workflowSchemaVersion': 1,
  'version': 1,
  'laneSetVersion': 1,
  'activeRedWork': false,
  'awaitingPreparation': false,
  'cancelled': false,
  'createdAt': _created,
  'updatedAt': _later,
};

Map<String, dynamic> _lane() => <String, dynamic>{
  'workflowId': 'workflow-1',
  'jobExecutionId': 'execution-1',
  'laneKey': 'mech',
  'status': 'pending',
  'activationGeneration': 1,
  'version': 1,
  'progressRevision': 0,
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'displayOrder': 0,
  'createdAt': _created,
  'updatedAt': _later,
};

Map<String, dynamic> _equipment() => <String, dynamic>{
  'version': 1,
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'state': 'inService',
  'activeNonRedMaintenanceCount': 0,
  'activeRedWorkCount': 0,
  'awaitingPreparationCount': 0,
  'previousState': 'inService',
  'updatedAt': _later,
};

Map<String, dynamic> _prompt() => <String, dynamic>{
  'version': 1,
  'assetTypeKey': 'furnace',
  'promptKey': 'placeOnStand',
  'promptTypeKey': 'question',
  'question': 'Place on stand?',
  'active': true,
  'createdAt': _created,
  'updatedAt': _later,
};

Map<String, dynamic> _event() => <String, dynamic>{
  'aggregateId': 'workflow-1',
  'eventType': 'workflowCreated',
  'payload': <String, dynamic>{},
  'occurredAt': _later,
};

Map<String, dynamic> _attempt() => <String, dynamic>{
  'complianceRequestId': 'compliance-1',
  'attemptNumber': 1,
  'attemptedByUid': 'actor-1',
  'attemptedAt': _later,
  'note': 'Condition confirmed',
  'accepted': false,
};

Map<String, dynamic> _compliance() => <String, dynamic>{
  'version': 1,
  'title': 'Guard repair',
  'description': 'Restore interlock guard',
  'targetLaneKey': 'mech',
  'status': 'raised',
  'conditionTypeKey': 'manual',
  'priorityKey': 'medium',
  'linkedWorkflowId': 'workflow-1',
  'assetTypeKey': 'furnace',
  'assetNumber': 7,
  'createdAt': _created,
  'updatedAt': _later,
  'isDeleted': false,
};
