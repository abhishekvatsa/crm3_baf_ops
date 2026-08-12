import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/published_runtime_module_catalogue.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/runtime_module_lineage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Runtime module lineage visibility contract', () {
    test('interprets governed runtime-add lineage metadata for display', () {
      final module = _governedRuntimeAddModule();

      final info = RuntimeModuleLineageInfo.fromModule(module);
      final rows = {for (final row in info.detailRows) row.label: row.value};

      expect(
        info.source,
        RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd,
      );
      expect(info.isGovernedPublishedSource, isTrue);
      expect(info.isEmergencyManualFallback, isFalse);
      expect(info.label, 'Published TemplateVersion runtime add');
      expect(info.badgeLabel, 'Published runtime add');
      expect(info.summary, contains('BAF-66C'));
      expect(info.summary, contains('v8 · runtime lineage'));
      expect(info.summary, contains('GOV-66C'));
      expect(info.warning, isNull);
      expect(rows['Package'], 'BAF-66C');
      expect(rows['Version'], 'v8 · runtime lineage');
      expect(rows['Module code'], 'GOV-66C');
      expect(rows['Template module id'], 'tm_66c_governed');
      expect(rows['Content hash'], startsWith('tg2-sha256:'));
      expect(
        rows['Runtime add reason'],
        'Added during active job from governed catalogue',
      );
    });

    test(
      'flags Emergency/manual seed fallback lineage from metadata source',
      () {
        final module =
            _seedFallbackModule()
              ..metadataJson = jsonEncode(<String, dynamic>{
                'source': 'baf_module_catalogue_seed',
                'seedVersion': 'manualCatalogueV0_2',
                'catalogueArea': 'BAF base',
              });

        final info = RuntimeModuleLineageInfo.fromModule(module);
        final rows = {for (final row in info.detailRows) row.label: row.value};

        expect(info.source, RuntimeModuleLineageSource.emergencyManualSeed);
        expect(info.isGovernedPublishedSource, isFalse);
        expect(info.isEmergencyManualFallback, isTrue);
        expect(info.label, 'Emergency/manual seed fallback');
        expect(info.badgeLabel, 'Emergency/manual seed');
        expect(info.summary, contains('manualCatalogueV0_2'));
        expect(info.summary, contains('BAF base'));
        expect(info.warning, contains('Fallback source'));
        expect(rows['Seed version'], 'manualCatalogueV0_2');
        expect(rows['Catalogue area'], 'BAF base');
        expect(rows['Module code'], 'EM-66C');
        expect(
          rows['Add reason'],
          'Temporary fallback until governed module is published',
        );
      },
    );

    test('detects legacy seed fallback without metadata source', () {
      final module =
          _seedFallbackModule()
            ..metadataJson = jsonEncode(<String, dynamic>{
              'legacyNote': 'no source',
            })
            ..moduleSnapshotJson = jsonEncode(<String, dynamic>{
              'source': 'baf_module_catalogue_seed',
              'seedVersion': 'legacySeedV1',
              'catalogueArea': 'Legacy fallback catalogue',
            });

      final info = RuntimeModuleLineageInfo.fromModule(module);
      final rows = {for (final row in info.detailRows) row.label: row.value};

      expect(info.source, RuntimeModuleLineageSource.emergencyManualSeed);
      expect(info.isEmergencyManualFallback, isTrue);
      expect(info.isGovernedPublishedSource, isFalse);
      expect(info.badgeLabel, 'Emergency/manual seed');
      expect(info.warning, contains('Fallback source'));
      expect(rows['Seed version'], 'legacySeedV1');
      expect(rows['Catalogue area'], 'Legacy fallback catalogue');
    });

    test('detects legacy seed fallback from broad seed source text', () {
      final module =
          _lineageBaseModule()
            ..templatePackageId = 'legacy package BAF_MODULE_CATALOGUE_SEED'
            ..templateVersionId = 'legacy runtime fallback'
            ..templateModuleId = 'legacy_seed_module'
            ..moduleCode = 'EM-66C-TEXT'
            ..addedDuringExecution = true
            ..metadataJson = null
            ..moduleSnapshotJson = jsonEncode(<String, dynamic>{
              'moduleCode': 'EM-66C-TEXT',
              'moduleTitle': 'Legacy text seed module',
            });

      final info = RuntimeModuleLineageInfo.fromModule(module);

      expect(info.source, RuntimeModuleLineageSource.emergencyManualSeed);
      expect(info.isEmergencyManualFallback, isTrue);
      expect(info.isGovernedPublishedSource, isFalse);
    });

    test(
      'distinguishes scheduled published snapshots from emergency fallback',
      () {
        final published =
            _lineageBaseModule()
              ..templatePackageId = 'package_66c'
              ..templateVersionId = 'version_66c'
              ..templateModuleId = 'tm_66c_scheduled'
              ..templateName = 'BAF-66C · v8 · runtime lineage'
              ..moduleCode = 'PUB-66C'
              ..addedDuringExecution = false;

        final fallback =
            _seedFallbackModule()
              ..metadataJson = null
              ..moduleSnapshotJson = jsonEncode(<String, dynamic>{
                'seedVersion': 'snapshotSeedV2',
                'catalogueArea': 'Snapshot fallback catalogue',
              });

        final publishedInfo = RuntimeModuleLineageInfo.fromModule(published);
        final fallbackInfo = RuntimeModuleLineageInfo.fromModule(fallback);

        expect(
          publishedInfo.source,
          RuntimeModuleLineageSource.publishedTemplateVersionModule,
        );
        expect(publishedInfo.isGovernedPublishedSource, isTrue);
        expect(publishedInfo.isEmergencyManualFallback, isFalse);
        expect(
          fallbackInfo.source,
          RuntimeModuleLineageSource.emergencyManualSeed,
        );
        expect(fallbackInfo.isGovernedPublishedSource, isFalse);
        expect(fallbackInfo.isEmergencyManualFallback, isTrue);
      },
    );

    test(
      'published runtime-add lineage survives map round trip and audit snapshot',
      () {
        final candidate =
            publishedRuntimeModuleCandidatesFromVersion(
              version: _publishedVersion(
                modules: [
                  _module(
                    code: 'BAF-LINEAGE-66C',
                    title: '66C governed lineage module',
                    requiredForClosure: true,
                    discipline: 'shared',
                    safetyClass: 'lotoRequired',
                  ),
                ],
                fields: [
                  _field(moduleCode: 'BAF-LINEAGE-66C', key: 'lineageEvidence'),
                ],
              ),
              package: _package(),
              assetType: AssetType.base,
            ).single;

        final module = candidate.toJobModuleInstance(
          execution: _execution(),
          actor: _supervisor(),
          now: DateTime.utc(2026, 5, 22, 11),
          addReason: '66C lineage visibility proof',
        );

        final map = module.toMap()..['firestoreId'] = 'module_66c_lineage';
        final restored = JobModuleInstance.fromMap(map, 'module_66c_lineage');
        final metadata =
            jsonDecode(restored.metadataJson!) as Map<String, dynamic>;
        final audit = restored.toAuditMap();
        final info = RuntimeModuleLineageInfo.fromModule(restored);

        expect(restored.addedDuringExecution, isTrue);
        expect(restored.templateFirestoreId, 'version_66c');
        expect(restored.templatePackageId, 'package_66c');
        expect(restored.templateVersionId, 'version_66c');
        expect(restored.templateModuleId, 'tm_BAF-LINEAGE-66C');
        expect(restored.moduleCode, 'BAF-LINEAGE-66C');
        expect(restored.templateName, contains('BAF-66C'));
        expect(restored.fieldDefinitionsJson, contains('lineageEvidence'));
        expect(restored.requiredForClosure, isTrue);
        expect(restored.discipline, JobModuleDiscipline.shared);
        expect(restored.safetyClass, JobModuleSafetyClass.lotoRequired);

        expect(metadata['source'], 'published_template_version_runtime_add');
        expect(metadata['packageFirestoreId'], 'package_66c');
        expect(metadata['packageCode'], 'BAF-66C');
        expect(metadata['packageTitle'], '66C runtime lineage package');
        expect(metadata['versionFirestoreId'], 'version_66c');
        expect(metadata['versionNumber'], 6);
        expect(metadata['versionLabel'], '66C lineage runtime add');
        expect(metadata['contentHash'], 'tg2-sha256:${'c' * 64}');
        expect(metadata['moduleIndex'], 0);
        expect(metadata['moduleCode'], 'BAF-LINEAGE-66C');
        expect(metadata['templateModuleId'], 'tm_BAF-LINEAGE-66C');
        expect(metadata['runtimeAddReason'], '66C lineage visibility proof');

        expect(
          info.source,
          RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd,
        );
        expect(info.isGovernedPublishedSource, isTrue);
        expect(info.isEmergencyManualFallback, isFalse);

        expect(audit['templateFirestoreId'], 'version_66c');
        expect(audit['templatePackageId'], 'package_66c');
        expect(audit['templateVersionId'], 'version_66c');
        expect(audit['templateModuleId'], 'tm_BAF-LINEAGE-66C');
        expect(audit['moduleCode'], 'BAF-LINEAGE-66C');
        expect(audit['addedDuringExecution'], isTrue);
        expect(audit['requiredForClosure'], isTrue);
      },
    );

    test(
      'scheduled published snapshots and emergency fallback carry distinct lineage signals through serialization',
      () {
        final scheduled =
            JobModuleInstance()
              ..firestoreId = 'scheduled_66c'
              ..jobExecutionFirestoreId = 'execution_66c'
              ..templateFirestoreId = 'version_66c'
              ..templatePackageId = 'package_66c'
              ..templateVersionId = 'version_66c'
              ..templateModuleId = 'tm_scheduled_66c'
              ..moduleCode = 'BAF-SCHEDULED-66C'
              ..moduleSnapshotJson = jsonEncode(<String, dynamic>{
                'moduleCode': 'BAF-SCHEDULED-66C',
                'moduleTitle': '66C scheduled frozen module',
              })
              ..fieldDefinitionsJson = '[]'
              ..assetType = AssetType.base
              ..assetNumber = 101
              ..moduleTitle = '66C scheduled frozen module'
              ..status = JobModuleStatus.notStarted
              ..useMode = JobModuleUseMode.scheduledPM
              ..discipline = JobModuleDiscipline.mechanical
              ..safetyClass = JobModuleSafetyClass.normal
              ..isRequired = false
              ..requiredForClosure = false
              ..addedDuringExecution = false
              ..displayOrder = 1
              ..responsesJson = '[]'
              ..actionsJson = '[]'
              ..requiresFollowUp = false
              ..createdAt = DateTime.utc(2026, 5, 22, 9)
              ..updatedAt = DateTime.utc(2026, 5, 22, 9)
              ..isDeleted = false
              ..version = 1;

        final emergency =
            JobModuleInstance()
              ..firestoreId = 'emergency_66c'
              ..jobExecutionFirestoreId = 'execution_66c'
              ..templateFirestoreId = 'seed:baf_module_catalogue_seed'
              ..templateModuleId = 'seed_BAF_EMERGENCY_66C'
              ..moduleCode = 'BAF-EMERGENCY-66C'
              ..moduleSnapshotJson = jsonEncode(<String, dynamic>{
                'moduleCode': 'BAF-EMERGENCY-66C',
                'moduleTitle': '66C emergency seed module',
                'source': 'baf_module_catalogue_seed',
                'seedVersion': '2026-05',
                'catalogueArea': 'BAF runtime fallback',
              })
              ..fieldDefinitionsJson = '[]'
              ..assetType = AssetType.base
              ..assetNumber = 101
              ..moduleTitle = '66C emergency seed module'
              ..status = JobModuleStatus.notStarted
              ..useMode = JobModuleUseMode.adHoc
              ..discipline = JobModuleDiscipline.mechanical
              ..safetyClass = JobModuleSafetyClass.normal
              ..isRequired = false
              ..requiredForClosure = false
              ..addedDuringExecution = true
              ..displayOrder = 2
              ..responsesJson = '[]'
              ..actionsJson = '[]'
              ..requiresFollowUp = false
              ..createdAt = DateTime.utc(2026, 5, 22, 9)
              ..updatedAt = DateTime.utc(2026, 5, 22, 9)
              ..metadataJson = jsonEncode(<String, dynamic>{
                'source': 'baf_module_catalogue_seed',
                'seedVersion': '2026-05',
                'catalogueArea': 'BAF runtime fallback',
              })
              ..isDeleted = false
              ..version = 1;

        final scheduledRoundTrip = JobModuleInstance.fromMap(
          scheduled.toMap(),
          'scheduled_66c',
        );
        final emergencyRoundTrip = JobModuleInstance.fromMap(
          emergency.toMap(),
          'emergency_66c',
        );
        final scheduledInfo = RuntimeModuleLineageInfo.fromModule(
          scheduledRoundTrip,
        );
        final emergencyInfo = RuntimeModuleLineageInfo.fromModule(
          emergencyRoundTrip,
        );

        expect(scheduledRoundTrip.addedDuringExecution, isFalse);
        expect(scheduledRoundTrip.templateVersionId, 'version_66c');
        expect(scheduledRoundTrip.templateFirestoreId, 'version_66c');
        expect(scheduledRoundTrip.templateModuleId, 'tm_scheduled_66c');
        expect(
          scheduledRoundTrip.toAuditMap()['addedDuringExecution'],
          isFalse,
        );
        expect(
          scheduledInfo.source,
          RuntimeModuleLineageSource.publishedTemplateVersionModule,
        );
        expect(scheduledInfo.isGovernedPublishedSource, isTrue);
        expect(scheduledInfo.isEmergencyManualFallback, isFalse);

        expect(emergencyRoundTrip.addedDuringExecution, isTrue);
        expect(
          emergencyRoundTrip.templateFirestoreId,
          'seed:baf_module_catalogue_seed',
        );
        expect(emergencyRoundTrip.templateModuleId, 'seed_BAF_EMERGENCY_66C');
        expect(
          emergencyRoundTrip.metadataJson,
          contains('baf_module_catalogue_seed'),
        );
        expect(emergencyRoundTrip.metadataJson, contains('seedVersion'));
        expect(emergencyRoundTrip.metadataJson, contains('catalogueArea'));
        expect(emergencyRoundTrip.toAuditMap()['addedDuringExecution'], isTrue);
        expect(
          emergencyInfo.source,
          RuntimeModuleLineageSource.emergencyManualSeed,
        );
        expect(emergencyInfo.isGovernedPublishedSource, isFalse);
        expect(emergencyInfo.isEmergencyManualFallback, isTrue);
      },
    );

    test(
      'dossier source display uses central lineage helper and preserves audit copy',
      () {
        final dossierSource =
            File(
              'lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart',
            ).readAsStringSync();
        final commonSource =
            File(
              'lib/features/planned_maintenance/presentation/dossier/planned_job_detail_common.dart',
            ).readAsStringSync();

        expect(dossierSource, contains('RuntimeModuleLineageInfo.fromModule'));
        expect(dossierSource, contains('RuntimeModuleLineageSource'));
        expect(dossierSource, isNot(contains('_decodeModuleJsonObject')));

        expect(dossierSource, contains('Published governed runtime addition'));
        expect(
          dossierSource,
          contains(
            'Added during active execution from the published governed TemplateVersion catalogue.',
          ),
        );

        expect(dossierSource, contains('Emergency/manual seed addition'));
        expect(
          dossierSource,
          contains('not from the published governed TemplateVersion'),
        );

        // Runtime-add and Emergency/manual seed badge labels come from the
        // central lineage helper at runtime rather than literal dossier copy.
        expect(dossierSource, contains('badgeLabel: lineage.badgeLabel'));

        expect(dossierSource, contains('Published TemplateVersion snapshot'));
        expect(dossierSource, contains('Published snapshot'));
        expect(
          dossierSource,
          contains(
            'This module was frozen from the published governed TemplateVersion assigned to this job.',
          ),
        );
        expect(dossierSource, contains('Manual runtime addition'));
        expect(dossierSource, contains('Legacy/manual module'));
        expect(dossierSource, contains('Closure-critical'));

        expect(commonSource, contains('class _MetadataBox'));
        expect(commonSource, contains("'Metadata'"));
        expect(commonSource, contains('_decodeMetadata'));
        expect(commonSource, contains('jsonDecode(raw)'));
      },
    );

    test('card and detail screens expose runtime lineage display hooks', () {
      final detailSource =
          File(
            'lib/features/planned_maintenance/presentation/job_module_detail_screen.dart',
          ).readAsStringSync();
      final cardSource =
          File(
            'lib/features/planned_maintenance/presentation/widgets/job_module_card.dart',
          ).readAsStringSync();

      expect(detailSource, contains('RuntimeModuleLineageInfo.fromModule'));
      expect(detailSource, contains("title: 'Source lineage'"));
      expect(detailSource, contains("label: 'Governance note'"));
      expect(detailSource, contains('lineage.detailRows'));
      expect(cardSource, contains('RuntimeModuleLineageInfo.fromModule'));
      expect(cardSource, contains("label: 'Source'"));
      expect(cardSource, contains('lineage.badgeLabel'));
    });
  });
}

JobModuleInstance _governedRuntimeAddModule() {
  return _lineageBaseModule()
    ..templatePackageId = 'package_66c'
    ..templateVersionId = 'version_66c'
    ..templateModuleId = 'tm_66c_governed'
    ..templateName = 'BAF-66C · v8 · runtime lineage'
    ..moduleCode = 'GOV-66C'
    ..addedDuringExecution = true
    ..addReason = 'Added during active job from governed catalogue'
    ..addedByName = 'Shift Supervisor 66C'
    ..metadataJson = jsonEncode(<String, dynamic>{
      'source': 'published_template_version_runtime_add',
      'packageFirestoreId': 'package_66c',
      'packageCode': 'BAF-66C',
      'packageTitle': 'Runtime lineage package',
      'versionFirestoreId': 'version_66c',
      'versionNumber': 8,
      'versionLabel': 'runtime lineage',
      'contentHash': 'tg2-sha256:${'c' * 64}',
      'moduleCode': 'GOV-66C',
      'templateModuleId': 'tm_66c_governed',
      'runtimeAddReason': 'Added during active job from governed catalogue',
    });
}

JobModuleInstance _seedFallbackModule() {
  return _lineageBaseModule()
    ..templatePackageId = 'seed:base'
    ..templateVersionId = 'seed:manualCatalogueV0_2'
    ..templateModuleId = 'seed:EM-66C'
    ..moduleCode = 'EM-66C'
    ..componentGroup = 'Emergency fallback'
    ..addedDuringExecution = true
    ..addReason = 'Temporary fallback until governed module is published'
    ..addedByName = 'Contract Supervisor 66C';
}

JobModuleInstance _lineageBaseModule() {
  return JobModuleInstance()
    ..moduleTitle = '66C lineage module'
    ..moduleCode = '66C-MOD'
    ..status = JobModuleStatus.notStarted
    ..useMode = JobModuleUseMode.scheduledPM
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..displayOrder = 1
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..fieldDefinitionsJson = '[]'
    ..createdAt = DateTime.utc(2026, 5, 22, 9)
    ..updatedAt = DateTime.utc(2026, 5, 22, 9);
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package_66c'
    ..packageCode = 'BAF-66C'
    ..title = '66C runtime lineage package';
}

TemplateVersion _publishedVersion({
  required List<Map<String, dynamic>> modules,
  required List<Map<String, dynamic>> fields,
}) {
  return TemplateVersion()
    ..firestoreId = 'version_66c'
    ..packageFirestoreId = 'package_66c'
    ..versionNumber = 6
    ..versionLabel = '66C lineage runtime add'
    ..status = TemplateVersionStatus.published
    ..contentHash = 'tg2-sha256:${'c' * 64}'
    ..jobTemplateSnapshotJson = jsonEncode(<String, dynamic>{
      'title': '66C runtime lineage',
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
    'functionalSection': '66C runtime lineage',
    'componentGroup': 'governed add module',
    'subsystem': 'BAF runtime module',
    'targetRefs': const ['BAF-BASE-01'],
    'procedureRefs': ['PROC-$code'],
    'safetyConfirmations': const ['Confirm safe job state'],
    'operationalStatePreconditions': const ['isolated'],
    'displayOrder': 1,
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
    ..firestoreId = 'execution_66c'
    ..templatePackageId = 'package_66c'
    ..templateVersionId = 'version_66c'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..chargeNoAtEvent = 6603
    ..createdAt = DateTime.utc(2026, 5, 22, 9)
    ..updatedAt = DateTime.utc(2026, 5, 22, 9);
}

AppUser _supervisor() {
  return AppUser(
    uid: 'shift_supervisor_66c',
    name: 'Shift Supervisor 66C',
    email: 'shift-supervisor-66c@example.com',
    roles: const [AppRole.shiftSupervisor],
    isApproved: true,
    createdAt: DateTime.utc(2026, 5, 22),
  );
}
