import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// These are actual dispatcher-produced records. Both the host producer test and
// the real Firestore transaction suite require exact fixture equality. Recreate
// only Firestore's native outer Timestamp transport; do not repair record data.
dynamic _native(dynamic value) {
  if (value is Map) {
    if (value.length == 2 &&
        value.containsKey('_seconds') &&
        value.containsKey('_nanoseconds')) {
      return Timestamp(value['_seconds'] as int, value['_nanoseconds'] as int);
    }
    return value.map((key, item) => MapEntry(key as String, _native(item)));
  }
  if (value is List) return value.map(_native).toList();
  return value;
}

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/red_preparation_dispatcher_records.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> row(Map<String, dynamic> source, String stage) =>
      _native(source[stage]) as Map<String, dynamic>;
  Map<String, dynamic> data(Map<String, dynamic> stage, String collection) =>
      (stage[collection] as Map)['data'] as Map<String, dynamic>;
  String id(Map<String, dynamic> stage, String collection) =>
      (stage[collection] as Map)['id'] as String;

  test('fixture includes both independent RED preparation producers', () {
    expect(fixture['schemaVersion'], 1);
    expect(cases.map((entry) => entry['route']).toSet(), {
      'generatedSuccessor',
      'preselectedLane',
    });
  });

  for (final source in cases) {
    final route = source['route'] as String;
    test('$route raised request and equipment are readable before release', () {
      final stage = row(source, 'raised');
      final workflow = workflowAggregateRecordFromFirestoreData(
        documentId: id(stage, 'workflow'),
        data: data(stage, 'workflow'),
      );
      final lane = jobLaneRecordFromFirestoreData(
        documentId: id(stage, 'lane'),
        data: data(stage, 'lane'),
      );
      final compliance = complianceRequestRecordFromFirestoreData(
        documentId: id(stage, 'compliance'),
        data: data(stage, 'compliance'),
      );
      final equipment = equipmentStatusRecordFromFirestoreData(
        documentId: id(stage, 'equipment'),
        data: data(stage, 'equipment'),
      );

      expect(workflow.awaitingPreparation, isTrue);
      expect(workflow.activeRedWork, isFalse);
      expect(lane.statusKey, 'pending');
      expect(lane.gatingComplianceRequestId, compliance.firestoreId);
      expect(compliance.linkedWorkflowId, workflow.firestoreId);
      expect(compliance.gatesLaneFirestoreId, 'job_lanes/${lane.firestoreId}');
      expect(compliance.priorityKey, 'medium');
      expect(compliance.assetTypeKey, 'furnace');
      expect(compliance.assetNumber, source['assetNumber']);
      expect(compliance.originLaneKey, 'red');
      expect(compliance.targetLaneKey, 'oprn');
      expect(compliance.raisedByUid, 'red-reader-admin');
      expect(compliance.statusKey, 'raised');
      expect(compliance.acknowledgementDueAt, isNotNull);
      expect(equipment.stateKey, 'awaitingPreparation');
      expect(equipment.awaitingPreparationCount, 1);
      expect(equipment.openRedCount, 0);
      expect(data(stage, 'compliance')['raisedAt'], isA<Timestamp>());
      final decision = data(stage, 'workflow')['redPreparationDecision'] as Map;
      expect(decision['preparationRequired'], isTrue);
      expect(decision['decidedByUid'], 'red-reader-admin');
      expect(decision['decidedAt'], isA<Timestamp>());
      expect(
        data(stage, 'lane')['redPreparationComplianceId'],
        compliance.firestoreId,
      );
    });

    test('$route confirmation releases RED and preserves readable history', () {
      final stage = row(source, 'released');
      final workflow = workflowAggregateRecordFromFirestoreData(
        documentId: id(stage, 'workflow'),
        data: data(stage, 'workflow'),
      );
      final lane = jobLaneRecordFromFirestoreData(
        documentId: id(stage, 'lane'),
        data: data(stage, 'lane'),
      );
      final compliance = complianceRequestRecordFromFirestoreData(
        documentId: id(stage, 'compliance'),
        data: data(stage, 'compliance'),
      );
      final equipment = equipmentStatusRecordFromFirestoreData(
        documentId: id(stage, 'equipment'),
        data: data(stage, 'equipment'),
      );

      expect(
        (source['confirmed'] as Map)['resultKey'],
        'red-preparation-confirmed',
      );
      expect(workflow.activeRedWork, isTrue);
      expect(workflow.awaitingPreparation, isFalse);
      expect(lane.statusKey, 'pending');
      expect(lane.gatingComplianceRequestId, isNull);
      expect(compliance.statusKey, 'confirmedClosed');
      expect(compliance.compliedByUid, 'red-reader-operations');
      expect(compliance.confirmedByUid, 'red-reader-refractory');
      expect(compliance.raisedByUid, 'red-reader-admin');
      expect(compliance.confirmedAt!.isBefore(compliance.compliedAt!), isFalse);
      expect(equipment.stateKey, 'underRED');
      expect(equipment.awaitingPreparationCount, 0);
      expect(equipment.openRedCount, 1);

      final ready = row(source, 'readyForWork');
      final acknowledgedLane = jobLaneRecordFromFirestoreData(
        documentId: id(ready, 'lane'),
        data: data(ready, 'lane'),
      );
      expect(acknowledgedLane.statusKey, 'acknowledged');
      expect(acknowledgedLane.acknowledgedByUid, 'red-reader-refractory');
      expect(acknowledgedLane.acknowledgedAt, isNotNull);
      expect(data(ready, 'compliance'), data(stage, 'compliance'));
    });

    for (final requiredField in [
      'priorityKey',
      'assetTypeKey',
      'assetNumber',
    ]) {
      test('$route still refuses a request without $requiredField', () {
        final stage = row(source, 'raised');
        final invalid = Map<String, dynamic>.from(data(stage, 'compliance'))
          ..remove(requiredField);
        expect(
          () => complianceRequestRecordFromFirestoreData(
            documentId: id(stage, 'compliance'),
            data: invalid,
          ),
          throwsFormatException,
        );
      });
    }
  }
}
