import 'dart:convert';

import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_published_sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'extracts cloneable modules from published TemplateVersion snapshots',
    () {
      final package = _package();
      final version = _publishedVersion();

      final sources = publishedModuleSourcesFromTemplateVersions(
        versions: [version],
        packages: [package],
      );

      expect(sources, hasLength(1));
      final source = sources.single;
      expect(source.packageCode, 'BAF-PKG');
      expect(source.packageTitle, 'BAF Published Package');
      expect(source.versionNumber, 3);
      expect(source.module.moduleCode, 'BASE-FAN-VIB');
      expect(source.module.fields.single.key, 'vt_reading');
      expect(source.module.checklistItems.single.id, 'BASE-FAN-VIB-item-1');
      expect(
        source.module.metadata['source'],
        'publishedTemplateVersionSnapshot',
      );
      expect(
        source.module.metadata['sourceTemplateVersionFirestoreId'],
        'version-3',
      );
    },
  );

  test('clones published source into a fresh editable draft module', () {
    final source =
        publishedModuleSourcesFromTemplateVersion(
          version: _publishedVersion(),
          package: _package(),
        ).single;

    final copy = clonePublishedModuleIntoDraft(
      source: source,
      existingModules: [source.module],
      now: DateTime.utc(2026, 1, 2),
    );

    expect(copy.localId, startsWith('module-copy-'));
    expect(copy.moduleCode, 'BASE-FAN-VIB-COPY');
    expect(copy.title, 'Base fan vibration check (copy)');
    expect(copy.metadata['source'], 'publishedTemplateVersionSnapshot');
    expect(copy.metadata['sourceModuleCode'], 'BASE-FAN-VIB');
    expect(copy.metadata['sourcePackageCode'], 'BAF-PKG');
    expect(
      copy.authoringNotes,
      contains('Cloned from published TemplateVersion BAF-PKG'),
    );

    copy.fields.single.validation['nested']['min'] = 99;
    expect(source.module.fields.single.validation['nested']['min'], 0);
  });

  test('ignores non-published or deleted versions', () {
    final draft = _publishedVersion()..status = TemplateVersionStatus.draft;
    final deleted = _publishedVersion()..isDeleted = true;

    final sources = publishedModuleSourcesFromTemplateVersions(
      versions: [draft, deleted],
      packages: [_package()],
    );

    expect(sources, isEmpty);
  });
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'package-1'
    ..packageCode = 'BAF-PKG'
    ..title = 'BAF Published Package'
    ..description = 'Published package fixture'
    ..assetType = 'base'
    ..assetNumberScope = '101-124'
    ..disciplineScope = 'mechanical'
    ..lifecycleStatus = TemplatePackageLifecycleStatus.active
    ..latestVersionNumber = 3
    ..isDeleted = false
    ..version = 1
    ..schemaVersion = 1
    ..isSynced = true
    ..createdAt = DateTime.utc(2026, 1, 1)
    ..updatedAt = DateTime.utc(2026, 1, 1);
}

TemplateVersion _publishedVersion() {
  return TemplateVersion()
    ..firestoreId = 'version-3'
    ..packageFirestoreId = 'package-1'
    ..versionNumber = 3
    ..versionLabel = 'Frozen source'
    ..status = TemplateVersionStatus.published
    ..contentHash = 'tg2-sha256:test'
    ..publishedAt = DateTime.utc(2026, 1, 1)
    ..createdAt = DateTime.utc(2026, 1, 1)
    ..updatedAt = DateTime.utc(2026, 1, 1)
    ..moduleSnapshotsJson = jsonEncode([
      {
        'moduleCode': 'BASE-FAN-VIB',
        'moduleTitle': 'Base fan vibration check',
        'moduleDescription': 'Capture base fan vibration reading.',
        'assetType': 'base',
        'discipline': 'shared',
        'useMode': 'scheduledPM',
        'functionalSection': 'Cooling fan',
        'componentGroup': 'Base fan',
        'subsystem': 'Fan vibration',
        'targetRefs': ['BASE-FAN'],
        'deviceTagRefs': ['VT-BASE-FAN'],
        'procedureRefs': ['BAF-FAN'],
        'operationalStatePreconditions': ['Fan running'],
        'requiredForClosure': true,
        'metadata': {
          'ownerDisciplines': ['mechanical', 'instrumentation'],
          'primaryOwner': 'mechanical',
          'requiresJointReview': true,
          'safetyClasses': ['rotatingEquipment'],
          'frequency': 'everyCharge',
          'authoringNotes': 'Published source fixture.',
        },
      },
    ])
    ..fieldDefinitionsJson = jsonEncode([
      {
        'moduleCode': 'BASE-FAN-VIB',
        'key': 'vt_reading',
        'label': 'VT reading',
        'type': 'numericWithUnit',
        'isRequired': true,
        'order': 1,
        'unit': 'mm/s',
        'validation': {
          'nested': {'min': 0},
        },
        'meta': {'isSafetyCriticalPreset': true},
      },
    ])
    ..checklistJson = jsonEncode([
      {
        'moduleCode': 'BASE-FAN-VIB',
        'id': 'BASE-FAN-VIB-item-1',
        'title': 'Confirm vibration reading captured',
        'isRequired': true,
        'order': 1,
        'safetyClasses': ['rotatingEquipment'],
        'metadata': {'source': 'published'},
      },
    ])
    ..jobTemplateSnapshotJson = jsonEncode({
      'title': 'Published source template',
      'assetType': 'base',
      'composer': {'closureReviewConfirmed': true},
    });
}
