import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/published_runtime_module_catalogue.dart';

void main() {
  group('Runtime add-module governed catalogue contract', () {
    test(
      'uses published TemplateVersion candidates and excludes already-attached modules by code or template id',
      () {
        final version = _publishedVersion(
          modules: [
            _module(
              code: 'BASE-FAN-01',
              templateModuleId: 'tm-base-fan-01',
              title: 'Already attached by code',
            ),
            _module(
              code: 'BASE-FAN-02',
              templateModuleId: 'tm-existing-template-id',
              title: 'Already attached by TemplateModuleId',
            ),
            _module(
              code: 'BASE-FAN-03',
              templateModuleId: 'tm-base-fan-03',
              title: 'New governed runtime module',
            ),
          ],
          fields: [
            _field(moduleRef: 'BASE-FAN-01', key: 'existingCodeField'),
            _field(moduleRef: 'BASE-FAN-02', key: 'existingIdField'),
            _field(moduleRef: 'BASE-FAN-03', key: 'newField'),
          ],
        );

        final candidates = publishedRuntimeModuleCandidatesFromVersion(
          version: version,
          package: _package(),
          assetType: AssetType.base,
          existingModuleCodes: {'base fan 01'},
          existingTemplateModuleIds: {'TM_EXISTING_TEMPLATE_ID'},
        );

        expect(candidates.map((candidate) => candidate.moduleCode), [
          'BASE-FAN-03',
        ]);
        expect(candidates.single.fieldDefinitionsJson, contains('newField'));
        expect(
          candidates.single.fieldDefinitionsJson,
          isNot(contains('existingCodeField')),
        );
        expect(
          candidates.single.fieldDefinitionsJson,
          isNot(contains('existingIdField')),
        );
      },
    );

    test(
      'creates runtime module from governed source with source lineage and no seed fallback metadata',
      () {
        final version = _publishedVersion(
          modules: [
            _module(
              code: 'SH-GAS-01',
              templateModuleId: 'tm-sh-gas-01',
              title: 'Shared gas verification',
              discipline: 'shared',
              safetyClass: 'gasRisk',
              requiredForClosure: true,
            ),
          ],
          fields: [_field(moduleRef: 'SH-GAS-01', key: 'gasValveLeakCheck')],
        );
        final candidate =
            publishedRuntimeModuleCandidatesFromVersion(
              version: version,
              package: _package(),
              assetType: AssetType.base,
            ).single;

        expect(candidate.requiresElevatedRuntimeAddControl(), isTrue);

        final module = candidate.toJobModuleInstance(
          execution: _execution(),
          actor: _actor(),
          now: DateTime.utc(2026, 5, 21, 9, 30),
          addReason:
              'Additional governed gas verification needed before close.',
        );

        final metadata =
            jsonDecode(module.metadataJson!) as Map<String, dynamic>;

        expect(module.addedDuringExecution, isTrue);
        expect(module.templatePackageId, 'package_66b_runtime');
        expect(module.templateVersionId, 'version_66b_runtime');
        expect(module.templateFirestoreId, 'version_66b_runtime');
        expect(module.templateModuleId, 'tm-sh-gas-01');
        expect(module.moduleCode, 'SH-GAS-01');
        expect(module.fieldDefinitionsJson, contains('gasValveLeakCheck'));
        expect(module.requiredForClosure, isTrue);
        expect(module.safetyClass, JobModuleSafetyClass.gasRisk);
        expect(module.discipline, JobModuleDiscipline.shared);
        expect(module.isSynced, isFalse);
        expect(metadata['source'], 'published_template_version_runtime_add');
        expect(metadata['packageFirestoreId'], 'package_66b_runtime');
        expect(metadata['versionFirestoreId'], 'version_66b_runtime');
        expect(metadata['moduleCode'], 'SH-GAS-01');
        expect(metadata['templateModuleId'], 'tm-sh-gas-01');
        expect(
          metadata['runtimeAddReason'],
          'Additional governed gas verification needed before close.',
        );
        expect(
          module.metadataJson,
          isNot(contains('baf_module_catalogue_seed')),
        );
        expect(module.metadataJson, isNot(contains('Emergency/manual seed')));
      },
    );

    test(
      'elevated runtime-add policy is controlled by safety class, shared lane, and closure requirement',
      () {
        final optionalNormal = _candidate(
          discipline: JobModuleDiscipline.mechanical,
          safetyClass: JobModuleSafetyClass.normal,
          requiredForClosure: false,
        );
        final closureCritical = _candidate(
          discipline: JobModuleDiscipline.mechanical,
          safetyClass: JobModuleSafetyClass.normal,
          requiredForClosure: true,
        );
        final sharedLane = _candidate(
          discipline: JobModuleDiscipline.shared,
          safetyClass: JobModuleSafetyClass.normal,
          requiredForClosure: false,
        );
        final safetyClassed = _candidate(
          discipline: JobModuleDiscipline.mechanical,
          safetyClass: JobModuleSafetyClass.lotoRequired,
          requiredForClosure: false,
        );

        expect(optionalNormal.requiresElevatedRuntimeAddControl(), isFalse);
        expect(closureCritical.requiresElevatedRuntimeAddControl(), isTrue);
        expect(sharedLane.requiresElevatedRuntimeAddControl(), isTrue);
        expect(safetyClassed.requiresElevatedRuntimeAddControl(), isTrue);
        expect(
          closureCritical.requiresElevatedRuntimeAddControl(
            requiredForClosureOverride: false,
          ),
          isFalse,
        );
      },
    );
  });
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package_66b_runtime'
    ..packageCode = 'BAF-66B'
    ..title = 'BAF 66B governed runtime catalogue';
}

TemplateVersion _publishedVersion({
  required List<Map<String, dynamic>> modules,
  required List<Map<String, dynamic>> fields,
}) {
  return TemplateVersion()
    ..firestoreId = 'version_66b_runtime'
    ..packageFirestoreId = 'package_66b_runtime'
    ..versionNumber = 7
    ..versionLabel = '66B runtime catalogue'
    ..status = TemplateVersionStatus.published
    ..contentHash = 'tg2-sha256:${'b' * 64}'
    ..jobTemplateSnapshotJson = jsonEncode({
      'title': '66B runtime catalogue',
      'assetType': 'base',
    })
    ..moduleSnapshotsJson = jsonEncode(modules)
    ..fieldDefinitionsJson = jsonEncode(fields)
    ..checklistJson = '[]';
}

Map<String, dynamic> _module({
  required String code,
  required String templateModuleId,
  required String title,
  String discipline = 'mechanical',
  String safetyClass = 'normal',
  bool requiredForClosure = false,
}) {
  return {
    'moduleCode': code,
    'templateModuleId': templateModuleId,
    'moduleTitle': title,
    'applicableAssetTypes': ['base'],
    'discipline': discipline,
    'safetyClass': safetyClass,
    'useMode': 'conditional',
    'requiredForClosure': requiredForClosure,
    'isRequired': requiredForClosure,
    'moduleDescription': '$title description',
    'functionalSection': 'runtime-add',
    'componentGroup': 'governed-catalogue',
    'subsystem': 'BAF base',
    'targetRefs': ['TAG-$code'],
    'procedureRefs': ['PROC-$code'],
    'safetyConfirmations': ['Confirm safe state'],
    'operationalStatePreconditions': ['isolated'],
    'displayOrder': code.endsWith('03') ? 30 : 10,
  };
}

Map<String, dynamic> _field({required String moduleRef, required String key}) {
  return {
    'moduleCode': moduleRef,
    'key': key,
    'label': 'Field $key',
    'type': 'text',
  };
}

JobExecution _execution() {
  return JobExecution()
    ..id = 66
    ..firestoreId = 'execution_66b'
    ..templateFirestoreId = 'version_66b_runtime'
    ..templateName = 'BAF 66B governed runtime job'
    ..templatePackageId = 'package_66b_runtime'
    ..templateVersionId = 'version_66b_runtime'
    ..templateVersionNumber = 7
    ..templateVersionLabel = '66B runtime catalogue'
    ..templatePackageCode = 'BAF-66B'
    ..templateContentHash = 'tg2-sha256:${'b' * 64}'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..chargeNoAtEvent = 16601
    ..createdAt = DateTime.utc(2026, 5, 21, 9)
    ..updatedAt = DateTime.utc(2026, 5, 21, 9);
}

AppUser _actor() {
  return AppUser(
    uid: 'shift_supervisor_66b',
    name: 'Shift Supervisor 66B',
    email: 'shift.supervisor.66b@example.com',
    roles: [AppRole.shiftSupervisor],
    isApproved: true,
    createdAt: DateTime.utc(2026, 5, 21),
  );
}

PublishedRuntimeModuleCandidate _candidate({
  required JobModuleDiscipline discipline,
  required JobModuleSafetyClass safetyClass,
  required bool requiredForClosure,
}) {
  return PublishedRuntimeModuleCandidate(
    packageFirestoreId: 'package_66b_runtime',
    packageCode: 'BAF-66B',
    packageTitle: 'BAF 66B governed runtime catalogue',
    versionFirestoreId: 'version_66b_runtime',
    versionNumber: 7,
    versionLabel: '66B runtime catalogue',
    contentHash: 'tg2-sha256:${'b' * 64}',
    moduleIndex: 0,
    moduleCode: 'TEST-66B',
    moduleTitle: 'Test 66B module',
    templateModuleId: 'tm-test-66b',
    moduleSnapshotJson: '{}',
    fieldDefinitionsJson: '[]',
    discipline: discipline,
    safetyClass: safetyClass,
    useMode: JobModuleUseMode.adHoc,
    requiredForClosure: requiredForClosure,
    isRequired: requiredForClosure,
    moduleDescription: 'Test module',
    functionalSection: 'runtime-add',
    componentGroup: 'governed-catalogue',
    subsystem: 'BAF base',
    targetRef: null,
    targetRefs: const [],
    procedureRefs: const [],
    safetyConfirmations: const [],
    operationalStatePreconditions: const [],
    tags: const [],
    displayOrder: 1,
  );
}
