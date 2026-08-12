import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';

void main() {
  group('Issue 41: response payload canonicalization', () {
    final response = FieldResponse(
      key: 'coilTemp',
      fieldLabel: 'Coil temperature',
      fieldType: FieldType.number,
      value: 720,
    );

    test(
      'JobModuleInstance writes responsesJson only, but reads legacy responses arrays',
      () {
        final now = DateTime.utc(2026, 5, 13, 1, 2, 3);
        final module =
            JobModuleInstance()
              ..firestoreId = 'module_1'
              ..jobExecutionFirestoreId = 'execution_1'
              ..moduleTitle = 'Sample module'
              ..assetType = AssetType.base
              ..assetNumber = 101
              ..status = JobModuleStatus.draftSaved
              ..discipline = JobModuleDiscipline.mechanical
              ..safetyClass = JobModuleSafetyClass.normal
              ..createdAt = now
              ..updatedAt = now
              ..createdByUid = 'u1'
              ..updatedByUid = 'u1'
              ..responses = [response];

        final map = module.toMap();

        expect(map.containsKey('responses'), isFalse);
        expect(map.containsKey('isSynced'), isFalse);
        expect(map['responsesJson'], isA<String>());
        expect(map['responsesJson'], contains('coilTemp'));

        final legacyMap =
            Map<String, dynamic>.from(map)
              ..['responses'] = [response.toMap()]
              ..remove('responsesJson');

        final parsed = JobModuleInstance.fromMap(legacyMap, 'module_1');
        expect(parsed.responses, hasLength(1));
        expect(parsed.responses.single.key, 'coilTemp');
        expect(parsed.responsesJson, contains('coilTemp'));
      },
    );

    test(
      'JobExecution writes responsesJson only, but reads legacy responses arrays',
      () {
        final now = DateTime.utc(2026, 5, 13, 1, 2, 3);
        final execution =
            JobExecution()
              ..firestoreId = 'execution_1'
              ..templateFirestoreId = 'template_1'
              ..templateName = 'Template'
              ..assetType = AssetType.base
              ..assetNumber = 101
              ..assignedByUid = 'u1'
              ..assignedAgencies = [RoutedTo.mechanical.name]
              ..createdAt = now
              ..updatedAt = now
              ..responses = [response];

        final map = execution.toMap();

        expect(map.containsKey('responses'), isFalse);
        expect(map['responsesJson'], isA<String>());
        expect(map['responsesJson'], contains('coilTemp'));

        final legacyMap =
            Map<String, dynamic>.from(map)
              ..['responses'] = [response.toMap()]
              ..remove('responsesJson');

        final parsed = JobExecution.fromMap(legacyMap, 'execution_1');
        expect(parsed.responses, hasLength(1));
        expect(parsed.responses.single.key, 'coilTemp');
        expect(parsed.responsesJson, contains('coilTemp'));
      },
    );

    test(
      'JobModuleInstance prefers canonical responsesJson when legacy responses also exists',
      () {
        final now = DateTime.utc(2026, 5, 13, 1, 2, 3);
        final legacy = FieldResponse(
          key: 'legacyKey',
          fieldLabel: 'Legacy response',
          fieldType: FieldType.text,
          value: 'from responses',
        );

        final parsed = JobModuleInstance.fromMap({
          'firestoreId': 'module_1',
          'jobExecutionFirestoreId': 'execution_1',
          'moduleTitle': 'Sample module',
          'assetType': 'base',
          'assetNumber': 101,
          'status': 'draftSaved',
          'discipline': 'mechanical',
          'safetyClass': 'normal',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'responsesJson':
              '[{"key":"canonicalKey","fieldLabel":"Canonical response","fieldType":"text","value":"from responsesJson"}]',
          'responses': [legacy.toMap()],
          'version': 1,
        }, 'module_1');

        expect(parsed.responses, hasLength(1));
        expect(parsed.responses.single.key, 'canonicalKey');
        expect(parsed.responsesJson, contains('canonicalKey'));
        expect(parsed.responsesJson, isNot(contains('legacyKey')));
      },
    );

    test(
      'JobExecution prefers canonical responsesJson when legacy responses also exists',
      () {
        final now = DateTime.utc(2026, 5, 13, 1, 2, 3);
        final legacy = FieldResponse(
          key: 'legacyKey',
          fieldLabel: 'Legacy response',
          fieldType: FieldType.text,
          value: 'from responses',
        );

        final parsed = JobExecution.fromMap({
          'firestoreId': 'execution_1',
          'templateFirestoreId': 'template_1',
          'templateName': 'Template',
          'assetType': 'base',
          'assetNumber': 101,
          'isCompleted': false,
          'isDeleted': false,
          'assignedByUid': 'u1',
          'assignedAgencies': ['mechanical'],
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'responsesJson':
              '[{"key":"canonicalKey","fieldLabel":"Canonical response","fieldType":"text","value":"from responsesJson"}]',
          'responses': [legacy.toMap()],
          'version': 1,
        }, 'execution_1');

        expect(parsed.responses, hasLength(1));
        expect(parsed.responses.single.key, 'canonicalKey');
        expect(parsed.responsesJson, contains('canonicalKey'));
        expect(parsed.responsesJson, isNot(contains('legacyKey')));
      },
    );
  });
}
