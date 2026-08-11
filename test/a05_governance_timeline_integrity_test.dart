import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 1, 10);
  final updatedAt = DateTime.utc(2026, 8, 1, 11);

  group('A-05 template governance timeline integrity', () {
    test('package timestamps and lifecycle state fail closed', () {
      final valid = _packageMap(createdAt: createdAt, updatedAt: updatedAt);
      final restored = TemplatePackage.fromMap(valid, 'package-1');
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);

      expect(
        () => TemplatePackage.fromMap(
          Map<String, dynamic>.from(valid)..remove('createdAt'),
          'package-1',
        ),
        _invalidField('createdAt'),
      );
      expect(
        () => TemplatePackage.fromMap(<String, dynamic>{
          ...valid,
          'updatedAt': 'not-a-time',
        }, 'package-1'),
        _invalidField('updatedAt'),
      );
      expect(
        () => TemplatePackage.fromMap(<String, dynamic>{
          ...valid,
          'lifecycleStatus': 'retired',
        }, 'package-1'),
        _invalidField('retiredAt'),
      );
      expect(
        () => TemplatePackage.fromMap(<String, dynamic>{
          ...valid,
          'lifecycleStatus': 'unknown',
        }, 'package-1'),
        _invalidField('lifecycleStatus'),
      );
    });

    test('version lifecycle history must be complete and state-consistent', () {
      final draft = _versionMap(createdAt: createdAt, updatedAt: updatedAt);
      expect(
        TemplateVersion.fromMap(draft, 'version-draft').status,
        TemplateVersionStatus.draft,
      );

      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'status': 'published',
          'contentHash': _contentHash,
          'publishedByUid': 'admin-1',
        }, 'version-draft'),
        _invalidField('publishedAt'),
      );
      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'status': 'retired',
          'contentHash': _contentHash,
          'publishedByUid': 'admin-1',
          'publishedAt': updatedAt.toIso8601String(),
          'retiredByUid': 'admin-1',
          'retireReason': 'Superseded by a governed revision',
        }, 'version-draft'),
        _invalidField('retiredAt'),
      );
      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'status': 'archived',
          'contentHash': _contentHash,
          'publishedByUid': 'admin-1',
          'publishedAt': updatedAt.toIso8601String(),
        }, 'version-draft'),
        _invalidField('retiredAt'),
      );
      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'jobTemplateSnapshotJson': jsonEncode(<String, dynamic>{
            'composer': <String, dynamic>{
              'closureReviewConfirmed': true,
              'closureReviewConfirmedByUid': 'admin-1',
            },
          }),
          'closureReviewConfirmed': true,
          'closureReviewConfirmedByUid': 'admin-1',
        }, 'version-draft'),
        _invalidField('closureReviewConfirmedAt'),
      );
      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'publishedAt': 'not-a-time',
        }, 'version-draft'),
        _invalidField('publishedAt'),
      );
      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ...draft,
          'jobTemplateSnapshotJson': jsonEncode(<String, dynamic>{
            'composer': <String, dynamic>{
              'closureReviewConfirmed': false,
              'closureReviewConfirmedAt': 'not-a-time',
            },
          }),
        }, 'version-draft'),
        _invalidField('closureReviewConfirmedAt'),
      );

      final retiredAt = DateTime.utc(2026, 8, 1, 13);
      final retired = TemplateVersion.fromMap(<String, dynamic>{
        ...draft,
        'status': 'retired',
        'contentHash': _contentHash,
        'publishedByUid': 'admin-1',
        'publishedAt': updatedAt.toIso8601String(),
        'retiredByUid': 'admin-1',
        'retiredAt': retiredAt.toIso8601String(),
        'retireReason': 'Superseded by a governed revision',
        'updatedAt': retiredAt.toIso8601String(),
      }, 'version-draft');
      expect(retired.publishedAt, updatedAt);
      expect(retired.retiredAt, retiredAt);
    });

    test('publication audits require their own exact timeline and action', () {
      final valid = _auditMap(createdAt: createdAt, updatedAt: updatedAt);
      final restored = TemplatePublishAudit.fromMap(valid, 'audit-1');
      expect(restored.performedAt, createdAt);
      expect(restored.updatedAt, updatedAt);

      expect(
        () => TemplatePublishAudit.fromMap(
          Map<String, dynamic>.from(valid)..remove('updatedAt'),
          'audit-1',
        ),
        _invalidField('updatedAt'),
      );
      expect(
        () => TemplatePublishAudit.fromMap(<String, dynamic>{
          ...valid,
          'performedAt': 'not-a-time',
        }, 'audit-1'),
        _invalidField('performedAt'),
      );
      expect(
        () => TemplatePublishAudit.fromMap(<String, dynamic>{
          ...valid,
          'action': 'unknown',
        }, 'audit-1'),
        _invalidField('action'),
      );
    });
  });

  group('A-05 module registry timeline integrity', () {
    test('families require complete lifecycle timestamps', () {
      final valid = _familyMap(createdAt: createdAt, updatedAt: updatedAt);
      final restored = ModuleRegistryFamily.fromMap(valid, 'family-1');
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);

      expect(
        () => ModuleRegistryFamily.fromMap(
          Map<String, dynamic>.from(valid)..remove('updatedAt'),
          'family-missing-updated',
        ),
        _invalidField('updatedAt'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'status': 'retired',
        }, 'family-retired-without-time'),
        _invalidField('retiredAt'),
      );
      expect(
        () => ModuleRegistryFamily.fromMap(<String, dynamic>{
          ...valid,
          'isDeleted': true,
        }, 'family-unsupported-tombstone'),
        _invalidField('isDeleted'),
      );
    });

    test('revisions require status-complete publication history', () {
      final draft = _revisionMap(createdAt: createdAt, updatedAt: updatedAt);
      expect(
        ModuleRegistryRevision.fromMap(draft, 'revision-draft').isDraft,
        isTrue,
      );

      expect(
        () => ModuleRegistryRevision.fromMap(<String, dynamic>{
          ...draft,
          'revisionStatus': 'published',
        }, 'revision-published-without-time'),
        _invalidField('publishedAt'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(<String, dynamic>{
          ...draft,
          'revisionStatus': 'retired',
          'publishedAt': updatedAt.toIso8601String(),
        }, 'revision-retired-without-time'),
        _invalidField('retiredAt'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(<String, dynamic>{
          ...draft,
          'publishedAt': updatedAt.toIso8601String(),
        }, 'revision-draft-with-history'),
        _invalidField('publishedAt'),
      );
      expect(
        () => ModuleRegistryRevision.fromMap(<String, dynamic>{
          ...draft,
          'revisionStatus': 'unknown',
        }, 'revision-unknown-state'),
        _invalidField('revisionStatus'),
      );
    });
  });

  test('governance decoders do not manufacture timeline timestamps', () {
    final templateSource =
        File(
          'lib/features/planned_maintenance/data/template_governance_model.dart',
        ).readAsStringSync();
    final registrySource =
        File(
          'lib/features/planned_maintenance/data/module_registry_model.dart',
        ).readAsStringSync();

    expect(
      templateSource,
      isNot(contains("_parseTimestamp(map['createdAt'])")),
    );
    expect(
      templateSource,
      isNot(contains("_parseTimestamp(map['updatedAt'])")),
    );
    expect(registrySource, isNot(contains('DateTime? _parseTimestamp')));
    expect(registrySource, contains('_rejectUnsupportedRegistryTombstone'));

    final publisherSource =
        File(
          'lib/features/planned_maintenance/presentation/template_publisher_screen.dart',
        ).readAsStringSync();
    expect(publisherSource, contains('e is PersistedDataFormatException'));
    expect(publisherSource, contains('Publishing is blocked'));
  });
}

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);

const _contentHash =
    'tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _packageMap({
  required DateTime createdAt,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'firestoreId': 'package-1',
  'packageCode': 'PKG-1',
  'title': 'Governed package',
  'lifecycleStatus': 'active',
  'latestVersionNumber': 0,
  'createdByUid': 'admin-1',
  'updatedByUid': 'admin-1',
  'version': 1,
  'schemaVersion': 1,
  'createdAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt.toIso8601String(),
  'isDeleted': false,
};

Map<String, dynamic> _versionMap({
  required DateTime createdAt,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'firestoreId': 'version-draft',
  'packageFirestoreId': 'package-1',
  'versionNumber': 1,
  'status': 'draft',
  'jobTemplateSnapshotJson': '{}',
  'moduleSnapshotsJson': '[]',
  'fieldDefinitionsJson': '[]',
  'checklistJson': '[]',
  'closureReviewConfirmed': false,
  'closureCriticalModuleCount': 0,
  'closureReviewConfirmedByUid': null,
  'closureReviewConfirmedByName': null,
  'closureReviewConfirmedAt': null,
  'createdByUid': 'admin-1',
  'updatedByUid': 'admin-1',
  'version': 1,
  'schemaVersion': 1,
  'createdAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt.toIso8601String(),
  'isDeleted': false,
};

Map<String, dynamic> _auditMap({
  required DateTime createdAt,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'firestoreId': 'audit-1',
  'packageFirestoreId': 'package-1',
  'versionFirestoreId': 'version-1',
  'action': 'created',
  'performedByUid': 'admin-1',
  'performedAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt.toIso8601String(),
  'version': 1,
  'schemaVersion': 1,
  'isDeleted': false,
};

Map<String, dynamic> _familyMap({
  required DateTime createdAt,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'registryModuleId': 'family-1',
  'moduleCode': 'MODULE-1',
  'canonicalTitle': 'Governed module',
  'status': 'active',
  'discipline': 'shared',
  'assetType': 'base',
  'createdAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt.toIso8601String(),
  'isDeleted': false,
};

Map<String, dynamic> _revisionMap({
  required DateTime createdAt,
  required DateTime updatedAt,
}) => <String, dynamic>{
  'registryModuleId': 'family-1',
  'revisionId': 'revision-1',
  'revisionNumber': 0,
  'revisionStatus': 'draft',
  'moduleSnapshotJson': '{}',
  'fieldDefinitionsJson': '[]',
  'checklistJson': '[]',
  'contentHash':
      'mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'lineageJson': '{}',
  'createdAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt.toIso8601String(),
  'isDeleted': false,
};
