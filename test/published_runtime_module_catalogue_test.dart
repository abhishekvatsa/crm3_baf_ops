import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/published_runtime_module_catalogue.dart';

void main() {
  group('PublishedRuntimeModuleCatalogue', () {
    test('builds candidates from a published TemplateVersion snapshot', () {
      final version = _publishedVersion(
        modules: [
          _module(
            code: 'B-FAN-01',
            title: 'Base fan inspection',
            assetTypes: ['base'],
            discipline: 'mechanical',
            safetyClass: 'normal',
            requiredForClosure: false,
          ),
        ],
        fields: [_field(moduleCode: 'B-FAN-01', key: 'vtReading')],
      );

      final candidates = publishedRuntimeModuleCandidatesFromVersion(
        version: version,
        package: _package(),
        assetType: AssetType.base,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.moduleCode, 'B-FAN-01');
      expect(candidates.single.fieldDefinitionsJson, contains('vtReading'));
      expect(candidates.single.sourceLabel, contains('BAF-RUNTIME'));
    });

    test(
      'filters modules that are not applicable to the active job asset type',
      () {
        final version = _publishedVersion(
          modules: [
            _module(code: 'B-01', title: 'Base module', assetTypes: ['base']),
            _module(
              code: 'F-01',
              title: 'Furnace module',
              assetTypes: ['furnace'],
            ),
          ],
          fields: [
            _field(moduleCode: 'B-01', key: 'baseField'),
            _field(moduleCode: 'F-01', key: 'furnaceField'),
          ],
        );

        final candidates = publishedRuntimeModuleCandidatesFromVersion(
          version: version,
          package: _package(),
          assetType: AssetType.base,
        );

        expect(candidates.map((candidate) => candidate.moduleCode), ['B-01']);
      },
    );

    test('can exclude modules already attached to the active job', () {
      final version = _publishedVersion(
        modules: [
          _module(code: 'B-01', title: 'Existing module'),
          _module(code: 'B-02', title: 'New runtime module'),
        ],
        fields: [
          _field(moduleCode: 'B-01', key: 'existingField'),
          _field(moduleCode: 'B-02', key: 'newField'),
        ],
      );

      final candidates = publishedRuntimeModuleCandidatesFromVersion(
        version: version,
        package: _package(),
        existingModuleCodes: {'B-01'},
      );

      expect(candidates.map((candidate) => candidate.moduleCode), ['B-02']);
    });

    test(
      'builds runtime-added JobModuleInstance with governed source metadata',
      () {
        final version = _publishedVersion(
          modules: [
            _module(
              code: 'SH-GAS-01',
              title: 'Shared gas valve verification',
              discipline: 'shared',
              safetyClass: 'gasRisk',
              requiredForClosure: true,
            ),
          ],
          fields: [_field(moduleCode: 'SH-GAS-01', key: 'tightShutoff')],
        );

        final candidate =
            publishedRuntimeModuleCandidatesFromVersion(
              version: version,
              package: _package(),
            ).single;
        final now = DateTime.utc(2026, 5, 12, 10, 30);

        final module = candidate.toJobModuleInstance(
          execution: _execution(),
          actor: _actor(),
          now: now,
          addReason:
              'Supervisor requested additional governed gas verification.',
        );

        expect(module.addedDuringExecution, isTrue);
        expect(module.templateVersionId, 'version_runtime_1');
        expect(module.templatePackageId, 'package_runtime_1');
        expect(module.templateModuleId, 'tm_SH-GAS-01');
        expect(module.moduleCode, 'SH-GAS-01');
        expect(module.requiredForClosure, isTrue);
        expect(module.safetyClass.name, 'gasRisk');
        expect(
          module.metadataJson,
          contains('published_template_version_runtime_add'),
        );
        expect(
          module.moduleSnapshotJson,
          contains('Shared gas valve verification'),
        );
        expect(module.fieldDefinitionsJson, contains('tightShutoff'));
        expect(candidate.requiresElevatedRuntimeAddControl(), isTrue);
      },
    );

    test('rejects draft TemplateVersions as runtime catalogue source', () {
      final draft = _publishedVersion(
        status: TemplateVersionStatus.draft,
        modules: [_module(code: 'B-01', title: 'Draft module')],
        fields: [_field(moduleCode: 'B-01', key: 'draftField')],
      );

      expect(
        () => publishedRuntimeModuleCandidatesFromVersion(version: draft),
        throwsStateError,
      );
    });
  });
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package_runtime_1'
    ..packageCode = 'BAF-RUNTIME'
    ..title = 'BAF governed runtime catalogue';
}

TemplateVersion _publishedVersion({
  required List<Map<String, dynamic>> modules,
  required List<Map<String, dynamic>> fields,
  TemplateVersionStatus status = TemplateVersionStatus.published,
}) {
  return TemplateVersion()
    ..firestoreId = 'version_runtime_1'
    ..packageFirestoreId = 'package_runtime_1'
    ..versionNumber = 3
    ..versionLabel = 'Runtime add package'
    ..status = status
    ..contentHash = 'tg2-sha256:${'a' * 64}'
    ..jobTemplateSnapshotJson = jsonEncode({
      'title': 'Runtime add package',
      'assetType': 'base',
    })
    ..moduleSnapshotsJson = jsonEncode(modules)
    ..fieldDefinitionsJson = jsonEncode(fields)
    ..checklistJson = '[]';
}

Map<String, dynamic> _module({
  required String code,
  required String title,
  List<String> assetTypes = const ['all'],
  String discipline = 'mechanical',
  String safetyClass = 'normal',
  bool requiredForClosure = false,
}) {
  return {
    'templateModuleId': 'tm_$code',
    'moduleCode': code,
    'moduleTitle': title,
    'applicableAssetTypes': assetTypes,
    'discipline': discipline,
    'safetyClass': safetyClass,
    'useMode': 'conditional',
    'requiredForClosure': requiredForClosure,
    'moduleDescription': '$title description',
    'functionalSection': 'runtime',
    'componentGroup': 'governed',
    'procedureRefs': ['PROC-$code'],
    'safetyConfirmations': ['Confirm safe state'],
    'operationalStatePreconditions': ['isolated'],
    'displayOrder': 10,
  };
}

Map<String, dynamic> _field({required String moduleCode, required String key}) {
  return {
    'moduleCode': moduleCode,
    'key': key,
    'label': 'Field $key',
    'type': 'text',
  };
}

JobExecution _execution() {
  return JobExecution()
    ..id = 42
    ..firestoreId = 'execution_1'
    ..templateFirestoreId = 'version_runtime_1'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..chargeNoAtEvent = 12345
    ..templateVersionId = 'version_runtime_1'
    ..templatePackageId = 'package_runtime_1'
    ..createdAt = DateTime.utc(2026, 5, 12, 9)
    ..updatedAt = DateTime.utc(2026, 5, 12, 9);
}

AppUser _actor() {
  return AppUser(
    uid: 'supervisor_1',
    name: 'Shift Supervisor',
    email: 'supervisor@example.com',
    roles: [AppRole.shiftSupervisor],
    isApproved: true,
    createdAt: DateTime.utc(2026, 5, 12),
  );
}
