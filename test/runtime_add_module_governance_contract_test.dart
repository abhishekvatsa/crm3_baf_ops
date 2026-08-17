import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/published_runtime_module_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools/testing/dart_library_source.dart';

void main() {
  group('Runtime add-module governance contract', () {
    test('active add-module UI prefers published catalogue before seed fallback', () {
      final detailSource =
          File(
            'lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart',
          ).readAsStringSync();
      final dossierSource =
          File(
            'lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart',
          ).readAsStringSync();
      final providerSource = readDartLibrarySource(
        'lib/features/planned_maintenance/providers/job_module_provider.dart',
      );

      expect(detailSource, contains('_loadPublishedRuntimeCatalogue'));
      expect(
        detailSource,
        contains('publishedRuntimeModuleCandidatesFromVersion'),
      );
      expect(
        detailSource,
        contains('publishedCatalogue.candidates.isNotEmpty'),
      );
      expect(detailSource, contains('_AddPublishedRuntimeModuleSheet'));
      expect(detailSource, contains('useEmergencyManualFallback'));
      expect(
        dossierSource,
        contains(
          'const _PublishedRuntimeModuleDraft.useEmergencyManualFallback()',
        ),
      );
      expect(detailSource, contains('Added published governed runtime module'));
      expect(
        detailSource,
        contains('Added Emergency/manual seed process module'),
      );

      expect(dossierSource, contains('Add governed process module'));
      expect(
        dossierSource,
        contains(
          'Preferred source: published TemplateVersion catalogue. Use Emergency/manual seed only as fallback.',
        ),
      );
      expect(dossierSource, contains('Use emergency/manual seed'));
      expect(
        dossierSource,
        contains(
          'Modules added here come from the Emergency/manual seed catalogue, ',
        ),
      );
      expect(
        dossierSource,
        contains('_canConfirmElevatedRuntimeModuleAddition'),
      );
      expect(
        dossierSource,
        contains('_canConfirmElevatedManualSeedModuleAddition'),
      );
      expect(
        dossierSource,
        contains('Supervisor/Admin/SI confirmation is required'),
      );

      expect(providerSource, contains('_requireCanAddModuleDuringExecution'));
      expect(providerSource, contains('_requireRuntimeModuleAddControl'));
      expect(providerSource, contains('_requiresElevatedRuntimeAddControl'));
    });

    test(
      'published runtime catalogue excludes modules already attached by templateModuleId',
      () {
        final version = _publishedVersion(
          modules: [
            _module(code: 'B-01', title: 'Already attached'),
            _module(code: 'B-02', title: 'Available add-on'),
          ],
          fields: [
            _field(moduleCode: 'B-01', key: 'existingField'),
            _field(moduleCode: 'B-02', key: 'availableField'),
          ],
        );

        final candidates = publishedRuntimeModuleCandidatesFromVersion(
          version: version,
          package: _package(),
          existingTemplateModuleIds: {'tm_B-01'},
        );

        expect(candidates.map((candidate) => candidate.moduleCode), ['B-02']);
        expect(
          candidates.single.fieldDefinitionsJson,
          contains('availableField'),
        );
      },
    );

    test('runtime add lineage metadata preserves governed source identity', () {
      final version = _publishedVersion(
        modules: [
          _module(
            code: 'SH-GAS-66B',
            title: '66B gas runtime add',
            discipline: 'shared',
            safetyClass: 'gasRisk',
            requiredForClosure: true,
          ),
        ],
        fields: [_field(moduleCode: 'SH-GAS-66B', key: 'gasEvidence')],
      );

      final candidate =
          publishedRuntimeModuleCandidatesFromVersion(
            version: version,
            package: _package(),
          ).single;
      final module = candidate.toJobModuleInstance(
        execution: _execution(),
        actor: _supervisor(),
        now: DateTime.utc(2026, 5, 22, 10),
        addReason: '66B governed add-module lineage proof',
      );
      final metadata = jsonDecode(module.metadataJson!) as Map<String, dynamic>;

      expect(module.addedDuringExecution, isTrue);
      expect(module.templatePackageId, 'package_66b');
      expect(module.templateVersionId, 'version_66b');
      expect(module.templateModuleId, 'tm_SH-GAS-66B');
      expect(module.moduleCode, 'SH-GAS-66B');
      expect(module.requiredForClosure, isTrue);
      expect(module.safetyClass.name, 'gasRisk');
      expect(module.fieldDefinitionsJson, contains('gasEvidence'));
      expect(module.isSynced, isFalse);

      expect(metadata['source'], 'published_template_version_runtime_add');
      expect(metadata['packageFirestoreId'], 'package_66b');
      expect(metadata['packageCode'], 'BAF-66B');
      expect(metadata['versionFirestoreId'], 'version_66b');
      expect(metadata['versionNumber'], 4);
      expect(metadata['contentHash'], startsWith('tg2-sha256:'));
      expect(metadata['moduleIndex'], 0);
      expect(metadata['moduleCode'], 'SH-GAS-66B');
      expect(metadata['templateModuleId'], 'tm_SH-GAS-66B');
      expect(
        metadata['runtimeAddReason'],
        '66B governed add-module lineage proof',
      );
      expect(candidate.requiresElevatedRuntimeAddControl(), isTrue);
    });

    test(
      'published runtime add elevation policy separates normal and critical modules',
      () {
        final version = _publishedVersion(
          modules: [
            _module(
              code: 'B-NORMAL-66B',
              title: 'Normal runtime add',
              discipline: 'mechanical',
              safetyClass: 'normal',
              requiredForClosure: false,
            ),
            _module(
              code: 'SH-CRIT-66B',
              title: 'Shared closure-critical runtime add',
              discipline: 'shared',
              safetyClass: 'gasRisk',
              requiredForClosure: true,
            ),
          ],
          fields: [
            _field(moduleCode: 'B-NORMAL-66B', key: 'normalField'),
            _field(moduleCode: 'SH-CRIT-66B', key: 'criticalField'),
          ],
        );

        final candidates = publishedRuntimeModuleCandidatesFromVersion(
          version: version,
          package: _package(),
        );
        final byCode = <String, PublishedRuntimeModuleCandidate>{
          for (final candidate in candidates) candidate.moduleCode: candidate,
        };

        expect(
          byCode['B-NORMAL-66B']!.requiresElevatedRuntimeAddControl(),
          isFalse,
        );
        expect(
          byCode['B-NORMAL-66B']!.requiresElevatedRuntimeAddControl(
            requiredForClosureOverride: true,
          ),
          isTrue,
        );
        expect(
          byCode['SH-CRIT-66B']!.requiresElevatedRuntimeAddControl(),
          isTrue,
        );
      },
    );
  });
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package_66b'
    ..packageCode = 'BAF-66B'
    ..title = '66B governed runtime add package';
}

TemplateVersion _publishedVersion({
  required List<Map<String, dynamic>> modules,
  required List<Map<String, dynamic>> fields,
}) {
  return TemplateVersion()
    ..firestoreId = 'version_66b'
    ..packageFirestoreId = 'package_66b'
    ..versionNumber = 4
    ..versionLabel = '66B runtime add governance'
    ..status = TemplateVersionStatus.published
    ..contentHash = 'tg2-sha256:${'b' * 64}'
    ..jobTemplateSnapshotJson = jsonEncode({
      'title': '66B runtime add',
      'assetType': 'base',
    })
    ..moduleSnapshotsJson = jsonEncode(modules)
    ..fieldDefinitionsJson = jsonEncode(fields)
    ..checklistJson = '[]';
}

Map<String, dynamic> _module({
  required String code,
  required String title,
  String discipline = 'mechanical',
  String safetyClass = 'normal',
  bool requiredForClosure = false,
}) {
  return <String, dynamic>{
    'templateModuleId': 'tm_$code',
    'moduleCode': code,
    'moduleTitle': title,
    'applicableAssetTypes': const ['base'],
    'discipline': discipline,
    'safetyClass': safetyClass,
    'useMode': 'scheduledPM',
    'requiredForClosure': requiredForClosure,
    'isRequired': requiredForClosure,
    'moduleDescription': '$title description',
    'functionalSection': '66B runtime governance',
    'componentGroup': 'governed add module',
    'subsystem': 'BAF runtime module',
    'targetRefs': ['BAF-BASE-01'],
    'procedureRefs': ['PROC-$code'],
    'safetyConfirmations': ['Confirm safe job state'],
    'operationalStatePreconditions': ['isolated'],
    'displayOrder': code.contains('NORMAL') ? 1 : 2,
  };
}

Map<String, dynamic> _field({required String moduleCode, required String key}) {
  return <String, dynamic>{
    'moduleCode': moduleCode,
    'key': key,
    'label': 'Field $key',
    'type': 'text',
  };
}

JobExecution _execution() {
  return JobExecution()
    ..id = 66
    ..firestoreId = 'execution_66b'
    ..templatePackageId = 'package_66b'
    ..templateVersionId = 'version_66b'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..chargeNoAtEvent = 6602
    ..createdAt = DateTime.utc(2026, 5, 22, 9)
    ..updatedAt = DateTime.utc(2026, 5, 22, 9);
}

AppUser _supervisor() {
  return AppUser(
    uid: 'shift_supervisor_66b',
    name: 'Shift Supervisor 66B',
    email: 'shift-supervisor-66b@example.com',
    roles: const [AppRole.shiftSupervisor],
    isApproved: true,
    createdAt: DateTime.utc(2026, 5, 22),
  );
}
