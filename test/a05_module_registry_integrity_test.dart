import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_registry_content_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 module registry family integrity', () {
    test(
      'restores exact governed state and retained pointer compatibility',
      () {
        final family = ModuleRegistryFamily.fromMap(_familyMap(), 'family-1');
        expect(family.registryModuleId, 'family-1');
        expect(family.discipline.name, 'shared');
        expect(family.assetType.name, 'base');
        expect(family.ownerDisciplines, <String>['mechanical']);
        expect(family.latestPublishedRevisionNumber, 0);

        final legacy = ModuleRegistryFamily.fromMap(<String, dynamic>{
          ..._familyMap(),
          'latestPublishedRevisionNumber': 3,
          'latestPublishedContentHash': _hashA,
        }, 'family-1');
        expect(legacy.latestPublishedRevisionNumber, 3);
        expect(legacy.latestPublishedRevisionId, isNull);
        expect(legacy.latestPublishedContentHash, _hashA);
      },
    );

    test('rejects manufactured identity, enum, list, bool, and counters', () {
      final valid = _familyMap();
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'registryModuleId': 'other',
        }, 'family-1'),
        _invalidField('registryModuleId'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(
          Map<String, dynamic>.from(valid)..remove('moduleCode'),
          'family-1',
        ),
        _invalidField('moduleCode'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'discipline': 'unknown',
        }, 'family-1'),
        _invalidField('discipline'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'ownerDisciplines': <Object>['mechanical', 7],
        }, 'family-1'),
        _invalidField('ownerDisciplines[1]'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'ownerDisciplines': null,
        }, 'family-1'),
        _invalidField('ownerDisciplines'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'requiredForClosure': 1,
        }, 'family-1'),
        _invalidField('requiredForClosure'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'latestPublishedRevisionNumber': -1,
        }, 'family-1'),
        _invalidField('latestPublishedRevisionNumber'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'version': 0,
        }, 'family-1'),
        _invalidField('version'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'schemaVersion': 2,
        }, 'family-1'),
        _invalidField('schemaVersion'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'latestPublishedContentHash': 'not-a-hash',
        }, 'family-1'),
        _invalidField('latestPublishedContentHash'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'latestPublishedRevisionId': 'revision-1',
        }, 'family-1'),
        _invalidField('latestPublishedRevisionNumber'),
      );
    });

    test('requires status-complete actor and ordered retirement history', () {
      final valid = _familyMap();
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'retiredByUid': 'admin-1',
        }, 'family-1'),
        _invalidField('retiredAt'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'status': 'retired',
          'retiredAt': _updatedAt,
          'retireReason': 'Governed retirement',
        }, 'family-1'),
        _invalidField('retiredByUid'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'status': 'retired',
          'retiredAt': '2026-07-31T23:59:00.000Z',
          'retiredByUid': 'admin-1',
          'retireReason': 'Governed retirement',
        }, 'family-1'),
        _invalidField('retiredAt'),
      );
    });
  });

  group('A-05 module registry revision integrity', () {
    test('restores exact draft identity, JSON, and canonical hash', () {
      final revision = ModuleRegistryRevision.fromMap(
        _revisionMap(),
        'revision-1',
        registryModuleId: 'family-1',
      );
      expect(revision.registryModuleId, 'family-1');
      expect(revision.revisionId, 'revision-1');
      expect(revision.revisionNumber, 0);
      expect(revision.isDraft, isTrue);
      expect(revision.contentHash, _revisionHash());

      const aliasSnapshot = '{"code":"MODULE-1"}';
      final alias = ModuleRegistryRevision.fromMap(
        _revisionMap(moduleSnapshotJson: aliasSnapshot),
        'revision-1',
        registryModuleId: 'family-1',
      );
      expect(alias.toComposerModuleDraft().moduleCode, 'MODULE-1');
    });

    test('rejects wrong path identity and missing required scalar state', () {
      final valid = _revisionMap();
      expect(
        () => ModuleRegistryRevision.fromMap(
          valid,
          'revision-1',
          registryModuleId: 'other-family',
        ),
        _invalidField('registryModuleId'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'revisionId': 'other'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('revisionId'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          Map<String, dynamic>.from(valid)..remove('revisionNumber'),
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('revisionNumber'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'revisionStatus': 'unknown'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('revisionStatus'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'createdByUid': 7},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('createdByUid'),
      );
    });

    test('rejects malformed JSON roots, references, lineage, and hash', () {
      final valid = _revisionMap();
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'moduleSnapshotJson': '[]'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('moduleSnapshotJson'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'fieldDefinitionsJson': '[7]'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('fieldDefinitionsJson[0]'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          _revisionMap(fieldDefinitionsJson: '[{"moduleCode":"OTHER"}]'),
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('fieldDefinitionsJson[0].moduleCode'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'lineageJson': '[]'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('lineageJson'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'contentHash': _hashA},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('contentHash'),
      );
    });

    test('requires lifecycle-complete publication and retirement evidence', () {
      final valid = _revisionMap();
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...valid, 'revisionStatus': 'published'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('revisionNumber'),
      );

      final published = <String, dynamic>{
        ...valid,
        'revisionNumber': 1,
        'revisionStatus': 'published',
        'publishedAt': _updatedAt,
        'publishedByUid': 'admin-1',
      };
      expect(
        ModuleRegistryRevision.fromMap(
          published,
          'revision-1',
          registryModuleId: 'family-1',
        ).isPublished,
        isTrue,
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...published}..remove('publishedByUid'),
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('publishedByUid'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(
          <String, dynamic>{...published, 'revisionStatus': 'retired'},
          'revision-1',
          registryModuleId: 'family-1',
        ),
        _invalidField('retiredAt'),
      );
    });

    test('source contains no top-level registry manufacturing defaults', () {
      final model =
          File(
            'lib/features/planned_maintenance/data/module_registry_model.dart',
          ).readAsStringSync();
      final reader =
          File(
            'lib/features/planned_maintenance/data/remote_module_registry_reader.dart',
          ).readAsStringSync();
      final provider =
          File(
            'lib/features/planned_maintenance/providers/module_registry_provider.dart',
          ).readAsStringSync();

      expect(model, contains('readRemoteModuleRegistryFamily'));
      expect(model, contains('readRemoteModuleRegistryRevision'));
      expect(model, isNot(contains('_enumByNameOr')));
      expect(model, isNot(contains('_cleanRequiredText')));
      expect(model, isNot(contains('_decodeJsonObject(')));
      expect(reader, contains('stableModuleRegistryContentHashStrict'));
      expect(
        RegExp(r'registryModuleId:').allMatches(provider).length,
        greaterThanOrEqualTo(
          RegExp(
            r'ModuleRegistryRevision\.fromMap\(',
          ).allMatches(provider).length,
        ),
      );
    });
  });
}

const String _createdAt = '2026-08-01T10:00:00.000Z';
const String _updatedAt = '2026-08-01T11:00:00.000Z';
const String _hashA =
    'mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _familyMap() => <String, dynamic>{
  'registryModuleId': 'family-1',
  'moduleCode': 'MODULE-1',
  'canonicalTitle': 'Governed module',
  'status': 'active',
  'discipline': 'shared',
  'ownerDisciplines': <String>['mechanical'],
  'assetType': 'base',
  'functionalSection': '',
  'componentGroup': '',
  'targetRefs': <String>[],
  'deviceTagRefs': <String>[],
  'safetyClasses': <String>[],
  'requiredForClosure': false,
  'latestPublishedRevisionNumber': 0,
  'createdByUid': 'admin-1',
  'createdAt': _createdAt,
  'updatedByUid': 'admin-1',
  'updatedAt': _updatedAt,
  'version': 1,
  'schemaVersion': 1,
  'isDeleted': false,
};

Map<String, dynamic> _revisionMap({
  String moduleSnapshotJson = '{"moduleCode":"MODULE-1"}',
  String fieldDefinitionsJson = '[]',
  String checklistJson = '[]',
}) => <String, dynamic>{
  'registryModuleId': 'family-1',
  'revisionId': 'revision-1',
  'revisionNumber': 0,
  'revisionStatus': 'draft',
  'moduleSnapshotJson': moduleSnapshotJson,
  'fieldDefinitionsJson': fieldDefinitionsJson,
  'checklistJson': checklistJson,
  'contentHash': _revisionHash(
    moduleSnapshotJson: moduleSnapshotJson,
    fieldDefinitionsJson: fieldDefinitionsJson,
    checklistJson: checklistJson,
  ),
  'lineageJson': '{}',
  'createdByUid': 'admin-1',
  'createdAt': _createdAt,
  'updatedByUid': 'admin-1',
  'updatedAt': _updatedAt,
  'version': 1,
  'schemaVersion': 1,
  'isDeleted': false,
};

String _revisionHash({
  String moduleSnapshotJson = '{"moduleCode":"MODULE-1"}',
  String fieldDefinitionsJson = '[]',
  String checklistJson = '[]',
}) => stableModuleRegistryContentHashStrict(
  moduleSnapshotJson: moduleSnapshotJson,
  fieldDefinitionsJson: fieldDefinitionsJson,
  checklistJson: checklistJson,
);

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);
