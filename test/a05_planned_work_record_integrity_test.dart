import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 planned-work persisted record integrity', () {
    test('current template, execution, module, and diary records decode', () {
      expect(JobTemplate.fromMap(_template(), 'template-1').version, 1);
      expect(JobExecution.fromMap(_execution(), 'execution-1').version, 1);
      expect(
        JobModuleInstance.fromMap(_module(), 'module-1').isOpenForWork,
        isTrue,
      );
      expect(JobDiaryEntry.fromMap(_diary(), 'diary-1').version, 1);
    });

    test('required identity and business state is never manufactured', () {
      _expectFormat(
        () => JobTemplate.fromMap(_template()..remove('jobName'), 'template-1'),
      );
      _expectFormat(
        () => JobExecution.fromMap(
          _execution()..['assetNumber'] = '101',
          'execution-1',
        ),
      );
      _expectFormat(
        () => JobModuleInstance.fromMap(
          _module()..remove('jobExecutionFirestoreId'),
          'module-1',
        ),
      );
      _expectFormat(
        () =>
            JobDiaryEntry.fromMap(_diary()..remove('updatedByUid'), 'diary-1'),
      );
    });

    test('embedded Firestore identities must match document identities', () {
      _expectFormat(
        () => JobTemplate.fromMap(
          _template()..['firestoreId'] = 'other',
          'template-1',
        ),
      );
      _expectFormat(
        () => JobExecution.fromMap(
          _execution()..['firestoreId'] = 'other',
          'execution-1',
        ),
      );
      _expectFormat(
        () => JobModuleInstance.fromMap(
          _module()..['firestoreId'] = 'other',
          'module-1',
        ),
      );
      _expectFormat(
        () => JobDiaryEntry.fromMap(
          _diary()..['firestoreId'] = 'other',
          'diary-1',
        ),
      );
    });

    test('malformed present compatibility fields fail closed', () {
      _expectFormat(
        () => JobTemplate.fromMap(
          _template()..['assignedAgencies'] = <Object>['ops', 4],
          'template-1',
        ),
      );
      _expectFormat(
        () => JobExecution.fromMap(
          _execution()..['laneMappingReview'] = 0,
          'execution-1',
        ),
      );
      _expectFormat(
        () => JobModuleInstance.fromMap(
          _module()..['status'] = 'invented',
          'module-1',
        ),
      );
      _expectFormat(
        () => JobDiaryEntry.fromMap(
          _diary()..['severity'] = 'invented',
          'diary-1',
        ),
      );
    });

    test('malformed local module snapshot blocks work payload admission', () {
      final module = JobModuleInstance.fromMap(_module(), 'module-1')
        ..moduleSnapshotJson = '{not-json';

      expect(module.moduleSnapshotReadResult.isValid, isFalse);
      expect(module.moduleSnapshotReadResult.value, isEmpty);

      final screenSource =
          File(
            'lib/features/planned_maintenance/presentation/job_module_detail_screen.dart',
          ).readAsStringSync();
      expect(screenSource, contains('snapshotRead.isValid &&'));
      expect(screenSource, contains("title: 'Module snapshot unavailable'"));
    });

    test('derived and lifecycle state cannot contradict persisted state', () {
      _expectFormat(
        () => JobExecution.fromMap(
          _execution()..['completedAt'] = _later,
          'execution-1',
        ),
      );
      _expectFormat(
        () => JobModuleInstance.fromMap(
          _module()..['isOpenForWork'] = false,
          'module-1',
        ),
      );
      _expectFormat(
        () => JobDiaryEntry.fromMap(
          _diary()
            ..['kind'] = JobDiaryKind.blocker.name
            ..['isBlocker'] = false,
          'diary-1',
        ),
      );
      _expectFormat(
        () =>
            JobDiaryEntry.fromMap(_diary()..['deletedAt'] = _later, 'diary-1'),
      );
    });

    test(
      'documented absent legacy module and diary fields remain compatible',
      () {
        final module =
            _module()
              ..remove('status')
              ..remove('discipline')
              ..remove('safetyClass')
              ..remove('isOpenForWork');
        final diary =
            _diary()
              ..remove('kind')
              ..remove('discipline')
              ..remove('severity')
              ..remove('isBlocker')
              ..remove('isHandover');

        expect(
          JobModuleInstance.fromMap(module, 'module-1').status,
          JobModuleStatus.notStarted,
        );
        expect(JobDiaryEntry.fromMap(diary, 'diary-1').kind, JobDiaryKind.note);
      },
    );
  });
}

void _expectFormat(void Function() decode) {
  expect(decode, throwsA(isA<PersistedDataFormatException>()));
}

const _created = '2026-08-12T08:00:00.000Z';
const _later = '2026-08-12T09:00:00.000Z';

Map<String, dynamic> _template() => <String, dynamic>{
  'firestoreId': 'template-1',
  'jobName': 'Pressure inspection',
  'applicableAssetType': AssetType.base.name,
  'isActive': true,
  'isDeprecated': false,
  'isDeleted': false,
  'version': 1,
  'createdAt': _created,
  'updatedAt': _later,
  'fields': <Object>[],
};

Map<String, dynamic> _execution() => <String, dynamic>{
  'firestoreId': 'execution-1',
  'templateFirestoreId': 'template-1',
  'assetType': AssetType.base.name,
  'assetNumber': 101,
  'assignedByUid': 'admin-1',
  'isCompleted': false,
  'isDeleted': false,
  'version': 1,
  'createdAt': _created,
  'updatedAt': _later,
  'responsesJson': '[]',
};

Map<String, dynamic> _module() => <String, dynamic>{
  'firestoreId': 'module-1',
  'jobExecutionFirestoreId': 'execution-1',
  'assetType': AssetType.base.name,
  'assetNumber': 101,
  'moduleTitle': 'Pressure inspection',
  'status': JobModuleStatus.draftSaved.name,
  'discipline': JobModuleDiscipline.mechanical.name,
  'safetyClass': JobModuleSafetyClass.normal.name,
  'isOpenForWork': true,
  'isDeleted': false,
  'version': 1,
  'createdAt': _created,
  'updatedAt': _later,
  'fieldDefinitionsJson': '[]',
  'responsesJson': '[]',
};

Map<String, dynamic> _diary() => <String, dynamic>{
  'firestoreId': 'diary-1',
  'assetType': AssetType.base.name,
  'assetNumber': 101,
  'kind': JobDiaryKind.note.name,
  'discipline': JobDiaryDiscipline.mechanical.name,
  'severity': JobDiarySeverity.medium.name,
  'isBlocker': false,
  'isHandover': false,
  'note': 'Checked alignment',
  'createdByUid': 'actor-1',
  'updatedByUid': 'actor-1',
  'isDeleted': false,
  'version': 1,
  'createdAt': _created,
  'updatedAt': _later,
};
