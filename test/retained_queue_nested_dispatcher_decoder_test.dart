import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Produced by the real dispatcher in produceRetainedQueueNestedEvidence.cjs.
// Backend tests compare fresh output with this fixture. These tests deliberately
// exercise lazy readers too: successful JobExecution.fromMap is insufficient.
void main() {
  final results =
      (jsonDecode(
                File(
                  'test/fixtures/retained_queue_nested_dispatcher_records.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> accepted(String id, String collection) {
    final result = results.singleWhere((row) => row['recordId'] == id);
    expect(result['collection'], collection);
    final record = Map<String, dynamic>.from(result['record'] as Map);
    expect(record['firestoreId'], id);
    return record;
  }

  JobExecution execution(String id) =>
      JobExecution.fromMap(accepted(id, 'job_executions'), id);

  test('accepted legacy template retains readable aliases and object bags', () {
    expect(results.map((row) => row['recordId']).toSet(), {
      'template-1',
      'execution-1',
      'legacy-execution',
      'cover-execution',
    });
    final raw = accepted('template-1', 'job_templates');
    final template = JobTemplate.fromMap(raw, 'template-1');
    expect(template.fieldsReadResult.isValid, true);
    final field = template.parsedFields.single;
    expect(field.key, 'inspection');
    expect(field.label, 'Inspection');
    expect(field.type, FieldType.text);
    expect(field.isRequired, false);
    expect(field.validation, {'maxLength': 200});
    expect(jsonDecode(field.validationJson!), {'maxLength': 200});
    expect(field.meta, {'note': 'legacy encoded bag'});
    // Exercise the encoded representation independently of eager `fields`.
    expect(
      TemplateField.decode(raw['fieldsJson'] as String).single.toMap(),
      field.toMap(),
    );
    final reference = template.assetHierarchyReference!;
    expect(reference.scope, AssetHierarchyReferenceScope.definition);
    expect(reference.nodeId, 'seal-node');
    expect(reference.ownershipStatus, AssetOwnershipStatus.unassigned);
    expect(raw['metadataJson'], '  ');
  });

  test(
    'accepted response aliases preserve null and bounded structured JSON',
    () {
      final record = execution('execution-1');
      expect(record.responsesReadResult.isValid, true);
      final responses = record.responses;
      expect(responses, hasLength(2));
      expect(responses.first.key, 'inspection');
      expect(responses.first.fieldType, FieldType.text);
      expect(responses.first.value, isNull);
      expect(responses.last.key, 'structured-observation');
      expect(responses.last.fieldType, FieldType.text);
      expect(responses.last.value, {
        'readings': [1, 2.5, null],
        'checked': true,
        'note': 'Synthetic bounded response',
        'details': {'units': 'mm'},
      });
    },
  );

  test('accepted legacy action preserves its original timestamp evidence', () {
    final record = execution('execution-1');
    expect(record.actionsReadResult.isValid, true);
    final action = record.actions.single;
    expect(action.actionType, ActionType.inspection);
    expect(action.asset, 'Furnace 1');
    expect(action.component, 'Seal');
    expect(action.isAutoResolved, false);
    expect(action.remarks, '');
    expect(action.createdAt, DateTime(2026, 9, 27, 0, 0, 20, 123, 456));
    expect(action.toMap()['createdAt'], '2026-09-27 00:00:20.123456');
    expect(
      action.assetHierarchyRef!.scope,
      AssetHierarchyReferenceScope.definition,
    );
  });

  test(
    'accepted work retains readable pinned identity and encoded snapshot',
    () {
      final record = execution('execution-1');
      expect(record.version, 2);
      expect(record.assignedByUid, 'si');
      expect(record.isCompleted, false);
      final identity = record.assignmentPhysicalAssetIdentity!;
      expect(identity.assetClassId, 'furnace-class');
      expect(identity.assetInstanceId, 'furnace-1');
      expect(identity.assetNumber, record.assetNumber);
      expect(record.assignmentAssetHierarchyReference!.nodeId, 'seal-node');
      expect(record.assignmentInnerCoverPositionReadResult.isValid, true);
      expect(record.assignmentInnerCoverPosition, isNull);
      expect((jsonDecode(record.metadataJson!) as Map)['operatorNote'], {
        'text': 'Original work',
        'shift': 2,
      });
    },
  );

  test(
    'accepted blank legacy metadata remains an absent optional identity',
    () {
      final raw = accepted('legacy-execution', 'job_executions');
      expect(raw['metadataJson'], ' ');
      expect(raw['remarks'], '');
      final record = JobExecution.fromMap(raw, 'legacy-execution');
      expect(record.remarks, '');
      expect(record.assignmentPhysicalAssetIdentity, isNull);
      expect(record.assignmentAssetHierarchyReference, isNull);
      expect(record.assignmentInnerCoverPositionReadResult.isValid, true);
      expect(record.assignmentInnerCoverPosition, isNull);
      expect(record.responsesReadResult.isValid, true);
      expect(record.actionsReadResult.isValid, true);
      expect(record.responses, isEmpty);
      expect(record.actions, isEmpty);
    },
  );

  test(
    'accepted exact Inner Cover assignment retains matching Base evidence',
    () {
      final record = execution('cover-execution');
      final identity = record.assignmentPhysicalAssetIdentity!;
      final position = record.assignmentInnerCoverPosition!;
      expect(record.assignmentInnerCoverPositionReadResult.isValid, true);
      expect(record.assignmentAssetHierarchyReference, isNull);
      expect(identity.assetClassId, 'base-class');
      expect(position.baseAssetClassId, identity.assetClassId);
      expect(position.baseAssetInstanceId, identity.assetInstanceId);
      expect(position.baseAssetNumber, identity.assetNumber);
      expect(position.innerCoverId, 'synthetic-cover');
      expect(position.innerCoverSerialNumber, 'DEV-IC-1');
      expect(position.linkageId, 'synthetic-link');
      expect(position.assignmentVersion, 2);
    },
  );

  test(
    'malformed responses and actions remain visible to strict readers',
    () {
      final raw = accepted('execution-1', 'job_executions')
        ..['responsesJson'] = '[{}]';
      final record = JobExecution.fromMap(raw, 'execution-1');
      expect(record.responsesReadResult.isValid, false);
      expect(
        () => record.responses,
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => JobExecution.fromMap(
          {...raw, 'actionsJson': '[{}]'},
          'execution-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    },
  );

  test(
    'present null assignment identity cannot masquerade as legacy absence',
    () {
      final raw = accepted('legacy-execution', 'job_executions')
        ..['metadataJson'] = '{"assignmentAssetIdentity":null}';
      final record = JobExecution.fromMap(raw, 'legacy-execution');
      expect(
        () => record.assignmentPhysicalAssetIdentity,
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(record.assignmentInnerCoverPositionReadResult.isValid, false);
    },
  );
}
