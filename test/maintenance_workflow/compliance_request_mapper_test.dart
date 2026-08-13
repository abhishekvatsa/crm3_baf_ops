import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';

void main() {
  test(
    'compliance Firestore projection preserves the complete lifecycle record',
    () {
      final instant = DateTime.utc(2026, 7, 21, 12, 34, 56);
      final record = complianceRequestRecordFromFirestoreData(
        documentId: 'cmp-1',
        data: <String, dynamic>{
          'version': 7,
          'title': 'Guard repair',
          'description': 'Restore interlock guard',
          'originLaneKey': 'mech',
          'targetLaneKey': 'oprn',
          'status': 'complied',
          'conditionTypeKey': 'activityRef',
          'conditionRef': 'activity-9',
          'requestPurposeKey': 'operationsSupport',
          'operationsSupportTypeKey': 'assetRelocation',
          'operationsResourceKey': 'crane',
          'requestedLocation': 'Maintenance bay 2',
          'raisedUnderCoordination': true,
          'coordinationBasis': 'supervisory-workflow-coordination',
          'priorityKey': 'high',
          'raisedByUid': 'u-raise',
          'raisedByName': 'Raiser',
          'raisedAt': instant,
          'acknowledgedByUid': 'u-ack',
          'acknowledgedByName': 'Acknowledger',
          'acknowledgedAt': instant,
          'compliedByUid': 'u-work',
          'compliedByName': 'Worker',
          'compliedAt': instant,
          'complianceNote': 'Completed safely',
          'currentAttemptId': 'attempt-2',
          'attemptCount': 2,
          'confirmedByUid': 'u-confirm',
          'confirmedByName': 'Confirmer',
          'confirmedAt': instant,
          'confirmNote': 'Verified',
          'becameDueAt': instant,
          'dueMarkedByUid': 'u-due',
          'dueMarkedByName': 'Due marker',
          'dueMarkedAt': instant,
          'counterDepth': 1,
          'counterConditionOfId': 'cmp-0',
          'supersededById': 'cmp-2',
          'counterProposal': <String, dynamic>{
            'proposedByUid': 'u-counter',
            'proposedByName': 'Counter proposer',
            'proposedAt': instant,
            'revisedDescription': 'Revised condition',
          },
          'counterDecision': <String, dynamic>{
            'decidedByUid': 'u-decide',
            'decidedByName': 'Decider',
            'decidedAt': instant,
            'note': 'Accepted',
          },
          'correctionCount': 3,
          'lastCorrectionByUid': 'u-correct',
          'lastCorrectionByName': 'Corrector',
          'lastCorrectionAt': instant,
          'lastCorrectionReason': 'Evidence unclear',
          'linkedWorkflowId': 'wf-1',
          'linkedMaintenanceFirestoreId': 'm-1',
          'linkedExecutionFirestoreId': 'e-1',
          'linkedLaneFirestoreId': 'l-1',
          'linkedModuleFirestoreId': 'mod-1',
          'gatesLaneFirestoreId': 'job_lanes/l-1',
          'assetTypeKey': 'furnace',
          'assetNumber': 7,
          'chargeNoAtEvent': 1234,
          'escalationTier': 2,
          'lastEscalatedAt': instant,
          'acknowledgementDueAt': instant,
          'complianceDueAt': instant,
          'createdAt': instant,
          'updatedAt': instant,
          'isDeleted': true,
          'deletedAt': instant,
          'deletedByUid': 'u-delete',
          'deletedByName': 'Deleter',
          'deleteReason': 'Duplicate',
          'metadata': <String, dynamic>{'source': 'test'},
        },
      );

      expect(record.firestoreId, 'cmp-1');
      expect(record.priorityKey, 'high');
      expect(record.requestPurposeKey, 'operationsSupport');
      expect(record.requestPurposeLabel, 'Operations support');
      expect(record.operationsSupportTypeKey, 'assetRelocation');
      expect(record.operationsResourceKey, 'crane');
      expect(record.requestedLocation, 'Maintenance bay 2');
      expect(record.raisedUnderCoordination, isTrue);
      expect(record.raisedByUid, 'u-raise');
      expect(record.acknowledgedByUid, 'u-ack');
      expect(record.compliedByUid, 'u-work');
      expect(record.confirmedByUid, 'u-confirm');
      expect(record.escalationTier, 2);
      expect(record.acknowledgementDueAt, instant);
      expect(record.complianceDueAt, instant);
      expect(record.counterDecisionByUid, 'u-decide');
      expect(record.lastCorrectionReason, 'Evidence unclear');
      expect(record.isDeleted, isTrue);
      expect(jsonDecode(record.metadataJson!), containsPair('source', 'test'));
    },
  );

  test('legacy compliance projection defaults to general assurance', () {
    final instant = DateTime.utc(2026, 7, 21);
    final record = complianceRequestRecordFromFirestoreData(
      documentId: 'legacy-assurance',
      data: <String, dynamic>{
        'version': 1,
        'title': 'Confirm isolation',
        'description': 'Confirm isolation before work.',
        'targetLaneKey': 'oprn',
        'status': 'raised',
        'conditionTypeKey': 'manual',
        'priorityKey': 'medium',
        'linkedWorkflowId': 'wf-1',
        'assetTypeKey': 'furnace',
        'assetNumber': 7,
        'createdAt': instant,
        'updatedAt': instant,
      },
    );

    expect(record.requestPurposeKey, 'assurance');
    expect(record.requestPurposeLabel, 'Assurance');
    expect(record.raisedUnderCoordination, isFalse);
  });

  test('authority-critical malformed compliance data fails closed', () {
    final base = <String, dynamic>{
      'version': 1,
      'title': 'Valid title',
      'description': 'Valid description',
      'targetLaneKey': 'mech',
      'status': 'raised',
      'conditionTypeKey': 'manual',
      'priorityKey': 'medium',
      'linkedWorkflowId': 'wf-1',
      'assetTypeKey': 'furnace',
      'assetNumber': 7,
      'createdAt': DateTime.utc(2026, 7, 21),
      'updatedAt': DateTime.utc(2026, 7, 21),
    };

    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-status',
        data: <String, dynamic>{...base, 'status': 'inventedState'},
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-support',
        data: <String, dynamic>{
          ...base,
          'requestPurposeKey': 'operationsSupport',
          'operationsSupportTypeKey': 'craneMovement',
          'operationsResourceKey': 'crane',
        },
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-coordination',
        data: <String, dynamic>{...base, 'raisedUnderCoordination': true},
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-coordination-basis',
        data: <String, dynamic>{
          ...base,
          'raisedUnderCoordination': true,
          'coordinationBasis': 'self-declared-supervisor',
        },
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-date',
        data: <String, dynamic>{...base, 'updatedAt': 'not-a-date'},
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-asset',
        data: <String, dynamic>{...base, 'assetNumber': 0},
      ),
      throwsFormatException,
    );
    expect(
      () => complianceRequestRecordFromFirestoreData(
        documentId: 'bad-title',
        data: <String, dynamic>{...base, 'title': 42},
      ),
      throwsFormatException,
    );
  });
}
