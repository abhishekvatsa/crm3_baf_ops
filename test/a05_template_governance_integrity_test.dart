import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools/testing/dart_library_source.dart';

const _contentHash =
    'tg2-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('A-05 template-package persisted integrity', () {
    test('complete package retains exact persisted authority', () {
      final package = TemplatePackage.fromMap(_validPackage(), 'package-1');

      expect(package.firestoreId, 'package-1');
      expect(package.packageCode, 'PKG-1');
      expect(package.lifecycleStatus, TemplatePackageLifecycleStatus.active);
      expect(package.latestVersionNumber, 2);
      expect(package.version, 3);
      expect(package.isSynced, isTrue);
    });

    test('every package authority field is required and exact', () {
      const required = <String>[
        'firestoreId',
        'packageCode',
        'title',
        'lifecycleStatus',
        'latestVersionNumber',
        'createdByUid',
        'updatedByUid',
        'version',
        'schemaVersion',
        'createdAt',
        'updatedAt',
        'isDeleted',
      ];
      for (final field in required) {
        final map = _validPackage()..remove(field);
        expect(
          () => TemplatePackage.fromMap(map, 'package-1'),
          _invalidField(field),
          reason: field,
        );
      }

      final malformed = <String, Object?>{
        'latestVersionNumber': '2',
        'version': 3.0,
        'schemaVersion': 0,
        'lifecycleStatus': 'unknown',
        'targetRefs': 'target-1',
        'metadataJson': <String, Object?>{},
      };
      for (final entry in malformed.entries) {
        expect(
          () => TemplatePackage.fromMap(<String, dynamic>{
            ..._validPackage(),
            entry.key: entry.value,
          }, 'package-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('identity, timeline, lists, and lifecycle state cannot drift', () {
      final cases = <String, Map<String, dynamic>>{
        'firestoreId': <String, dynamic>{
          ..._validPackage(),
          'firestoreId': 'package-2',
        },
        'updatedAt': <String, dynamic>{
          ..._validPackage(),
          'updatedAt': '2026-08-09T09:59:59.000Z',
        },
        'targetRefs': <String, dynamic>{
          ..._validPackage(),
          'targetRefs': <String>['base:1', 'base:1'],
        },
        'lifecycleStatus': <String, dynamic>{
          ..._validPackage(),
          'retiredAt': '2026-08-09T10:30:00.000Z',
        },
        'isDeleted': <String, dynamic>{
          ..._validPackage(),
          'deletedAt': '2026-08-09T10:30:00.000Z',
        },
      };

      for (final entry in cases.entries) {
        expect(
          () => TemplatePackage.fromMap(entry.value, 'package-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });
  });

  group('A-05 template-version persisted integrity', () {
    test('complete draft and published records retain exact authority', () {
      final draft = TemplateVersion.fromMap(_validVersion(), 'version-1');
      expect(draft.status, TemplateVersionStatus.draft);
      expect(draft.closureReviewConfirmed, isFalse);
      expect(draft.closureCriticalModuleCount, 0);

      final published = TemplateVersion.fromMap(
        _validPublishedVersion(),
        'version-1',
      );
      expect(published.status, TemplateVersionStatus.published);
      expect(published.contentHash, _contentHash);
      expect(published.closureReviewConfirmed, isTrue);
      expect(published.closureCriticalModuleCount, 1);
      expect(published.closureReviewConfirmedByUid, 'si-1');
    });

    test('every version authority field is required and exact', () {
      const required = <String>[
        'firestoreId',
        'packageFirestoreId',
        'versionNumber',
        'status',
        'jobTemplateSnapshotJson',
        'moduleSnapshotsJson',
        'fieldDefinitionsJson',
        'checklistJson',
        'createdByUid',
        'updatedByUid',
        'version',
        'schemaVersion',
        'createdAt',
        'updatedAt',
        'isDeleted',
      ];
      for (final field in required) {
        final map = _validVersion()..remove(field);
        expect(
          () => TemplateVersion.fromMap(map, 'version-1'),
          _invalidField(field),
          reason: field,
        );
      }

      final malformed = <String, Object?>{
        'versionNumber': '1',
        'status': 'unknown',
        'version': 1.0,
        'schemaVersion': 0,
        'isDeleted': 0,
        'deviceTagRefs': <Object?>['tag-1', 2],
        'metadataJson': '[]',
      };
      for (final entry in malformed.entries) {
        expect(
          () => TemplateVersion.fromMap(<String, dynamic>{
            ..._validVersion(),
            entry.key: entry.value,
          }, 'version-1'),
          _invalidField(
            entry.key == 'deviceTagRefs' ? 'deviceTagRefs[1]' : entry.key,
          ),
          reason: entry.key,
        );
      }
    });

    test('all four snapshot JSON fields are structurally strict', () {
      final malformed = <String, Object?>{
        'jobTemplateSnapshotJson': '{broken',
        'moduleSnapshotsJson': '{}',
        'fieldDefinitionsJson': '["not-an-object"]',
        'checklistJson': 7,
      };
      for (final entry in malformed.entries) {
        final expected =
            entry.key == 'fieldDefinitionsJson'
                ? 'fieldDefinitionsJson[0]'
                : entry.key;
        expect(
          () => TemplateVersion.fromMap(<String, dynamic>{
            ..._validVersion(),
            entry.key: entry.value,
          }, 'version-1'),
          _invalidField(expected),
          reason: entry.key,
        );
      }
    });

    test('local closure-state derivation rejects malformed snapshot state', () {
      final malformedJson =
          TemplateVersion()
            ..jobTemplateSnapshotJson = '{broken'
            ..moduleSnapshotsJson = '[]';
      expect(
        malformedJson.refreshClosureReviewStateFromSnapshots,
        _invalidField('jobTemplateSnapshotJson'),
      );

      final wrongBool =
          TemplateVersion()
            ..jobTemplateSnapshotJson = jsonEncode(<String, dynamic>{
              'composer': <String, dynamic>{'closureReviewConfirmed': 'yes'},
            })
            ..moduleSnapshotsJson = '[]';
      expect(
        wrongBool.refreshClosureReviewStateFromSnapshots,
        _invalidField('closureReviewConfirmed'),
      );

      final wrongCount =
          TemplateVersion()
            ..jobTemplateSnapshotJson = jsonEncode(<String, dynamic>{
              'closureCriticalCount': 1.0,
            })
            ..moduleSnapshotsJson = '[]';
      expect(
        wrongCount.refreshClosureReviewStateFromSnapshots,
        _invalidField('closureCriticalCount'),
      );
    });

    test('closure projection is complete, exact, and snapshot-bound', () {
      final partial = _validVersion()..remove('closureReviewConfirmedAt');
      expect(
        () => TemplateVersion.fromMap(partial, 'version-1'),
        _invalidField('closureReviewConfirmed'),
      );

      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ..._validPublishedVersion(),
          'closureCriticalModuleCount': 0,
        }, 'version-1'),
        _invalidField('closureReviewConfirmed'),
      );

      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ..._validVersion(),
          'moduleSnapshotsJson': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'requiredForClosure': true, 'required': false},
          ]),
        }, 'version-1'),
        _invalidField('moduleSnapshotsJson[0].required'),
      );

      expect(
        () => TemplateVersion.fromMap(<String, dynamic>{
          ..._validVersion(),
          'jobTemplateSnapshotJson': jsonEncode(<String, dynamic>{
            'composer': 'not-an-object',
          }),
        }, 'version-1'),
        _invalidField('jobTemplateSnapshotJson.composer'),
      );
    });

    test('whole legacy closure projection may be derived, partial may not', () {
      final legacy = _validPublishedVersion();
      for (final field in const <String>[
        'closureReviewConfirmed',
        'closureCriticalModuleCount',
        'closureReviewConfirmedByUid',
        'closureReviewConfirmedByName',
        'closureReviewConfirmedAt',
      ]) {
        legacy.remove(field);
      }

      final restored = TemplateVersion.fromMap(legacy, 'version-1');
      expect(restored.closureReviewConfirmed, isTrue);
      expect(restored.closureCriticalModuleCount, 1);
      expect(restored.closureReviewConfirmedByUid, 'si-1');
    });

    test('published and deletion lifecycle evidence is complete', () {
      final cases = <String, Map<String, dynamic>>{
        'publishedByUid': <String, dynamic>{
          ..._validPublishedVersion(),
          'publishedByUid': null,
        },
        'contentHash': <String, dynamic>{
          ..._validPublishedVersion(),
          'contentHash': 'not-a-governed-hash',
        },
        'publishedAt': <String, dynamic>{
          ..._validPublishedVersion(),
          'publishedAt': '2026-08-09T12:01:00.000Z',
        },
        'isDeleted': <String, dynamic>{
          ..._validVersion(),
          'deletedAt': '2026-08-09T11:00:00.000Z',
        },
      };
      for (final entry in cases.entries) {
        expect(
          () => TemplateVersion.fromMap(entry.value, 'version-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });
  });

  group('A-05 template-publish-audit persisted integrity', () {
    test('complete lifecycle audit retains exact evidence', () {
      final audit = TemplatePublishAudit.fromMap(_validAudit(), 'audit-1');
      expect(audit.action, TemplatePublishAuditAction.published);
      expect(audit.performedByUid, 'admin-1');
      expect(audit.afterHash, _contentHash);
      expect(audit.isSynced, isTrue);
    });

    test(
      'audit identity, timeline, versions, hashes, and payload fail closed',
      () {
        final cases = <String, Map<String, dynamic>>{
          'firestoreId': <String, dynamic>{
            ..._validAudit(),
            'firestoreId': 'audit-2',
          },
          'updatedAt': <String, dynamic>{
            ..._validAudit(),
            'updatedAt': '2026-08-09T09:59:59.000Z',
          },
          'version': <String, dynamic>{..._validAudit(), 'version': '1'},
          'schemaVersion': <String, dynamic>{
            ..._validAudit(),
            'schemaVersion': 0,
          },
          'afterHash': <String, dynamic>{
            ..._validAudit(),
            'afterHash': 'bad-hash',
          },
          'payloadSnapshotJson': <String, dynamic>{
            ..._validAudit(),
            'payloadSnapshotJson': '[]',
          },
        };
        for (final entry in cases.entries) {
          expect(
            () => TemplatePublishAudit.fromMap(entry.value, 'audit-1'),
            _invalidField(entry.key),
            reason: entry.key,
          );
        }
      },
    );

    test('archive and restore audits require substantive reason evidence', () {
      for (final action in <String>['archived', 'restored']) {
        expect(
          () => TemplatePublishAudit.fromMap(<String, dynamic>{
            ..._validAudit(),
            'action': action,
            'reason': 'too short',
          }, 'audit-1'),
          _invalidField('reason'),
          reason: action,
        );
      }
    });
  });

  test('factories and every Firestore page use the strict readers', () {
    final model =
        File(
          'lib/features/planned_maintenance/data/template_governance_model.dart',
        ).readAsStringSync();
    final reader =
        File(
          'lib/features/planned_maintenance/data/remote_template_governance_reader.dart',
        ).readAsStringSync();
    final provider = readDartLibrarySource(
      'lib/features/planned_maintenance/providers/template_governance_provider.dart',
    );

    expect(model, contains('readRemoteTemplatePackage('));
    expect(model, contains('readRemoteTemplateVersion('));
    expect(model, contains('readRemoteTemplatePublishAudit('));
    expect(reader, contains('the five closure-review projection fields'));
    expect(reader, contains('top-level closure review must match'));
    expect(reader, contains('must match the document ID'));
    expect(provider, contains('TemplatePackage.fromMap(doc.data(), doc.id)'));
    expect(provider, contains('TemplateVersion.fromMap(doc.data(), doc.id)'));
    expect(
      provider,
      contains('TemplatePublishAudit.fromMap(doc.data(), doc.id)'),
    );
  });
}

Map<String, dynamic> _validPackage() => <String, dynamic>{
  'firestoreId': 'package-1',
  'packageCode': 'PKG-1',
  'title': 'Governed package',
  'description': 'A governed planned-maintenance package.',
  'assetType': 'base',
  'assetNumberScope': '1-10',
  'disciplineScope': 'shared',
  'lifecycleStatus': 'active',
  'activeVersionFirestoreId': 'version-1',
  'latestVersionNumber': 2,
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
  'retiredByUid': null,
  'retiredByName': null,
  'retiredAt': null,
  'retireReason': null,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
  'version': 3,
  'schemaVersion': 1,
  'createdAt': '2026-08-09T10:00:00.000Z',
  'updatedAt': '2026-08-09T12:00:00.000Z',
  'targetRefs': <String>['base:1'],
  'deviceTagRefs': <String>['BASE_1_TEMP'],
  'safetyClass': 'standard',
  'safetyGatePolicyJson': '{"required":true}',
  'procedureRefs': <String>['PROC-1'],
  'operationalStatePreconditions': <String>['isolated'],
  'metadataJson': '{"source":"governed"}',
};

Map<String, dynamic> _validVersion() => <String, dynamic>{
  'firestoreId': 'version-1',
  'packageFirestoreId': 'package-1',
  'versionNumber': 1,
  'versionLabel': 'Draft 1',
  'status': 'draft',
  'sourceVersionFirestoreId': null,
  'contentHash': null,
  'jobTemplateSnapshotJson': '{}',
  'moduleSnapshotsJson': '[]',
  'fieldDefinitionsJson': '[]',
  'checklistJson': '[]',
  'releaseNotes': null,
  'changeSummary': null,
  'closureReviewConfirmed': false,
  'closureCriticalModuleCount': 0,
  'closureReviewConfirmedByUid': null,
  'closureReviewConfirmedByName': null,
  'closureReviewConfirmedAt': null,
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
  'publishedByUid': null,
  'publishedByName': null,
  'publishedAt': null,
  'retiredByUid': null,
  'retiredByName': null,
  'retiredAt': null,
  'retireReason': null,
  'minAppVersion': null,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
  'version': 2,
  'schemaVersion': 1,
  'createdAt': '2026-08-09T10:00:00.000Z',
  'updatedAt': '2026-08-09T12:00:00.000Z',
  'targetRefs': <String>[],
  'deviceTagRefs': <String>[],
  'safetyClass': null,
  'safetyGatePolicyJson': null,
  'procedureRefs': <String>[],
  'operationalStatePreconditions': <String>[],
  'metadataJson': null,
};

Map<String, dynamic> _validPublishedVersion() {
  const confirmationTime = '2026-08-09T10:30:00.000Z';
  return <String, dynamic>{
    ..._validVersion(),
    'status': 'published',
    'contentHash': _contentHash,
    'jobTemplateSnapshotJson': jsonEncode(<String, dynamic>{
      'closureCriticalCount': 1,
      'composer': <String, dynamic>{
        'closureReviewConfirmed': true,
        'closureReviewConfirmedByUid': 'si-1',
        'closureReviewConfirmedByName': 'Senior Inspector',
        'closureReviewConfirmedAt': confirmationTime,
      },
    }),
    'moduleSnapshotsJson': jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{'requiredForClosure': true},
    ]),
    'closureReviewConfirmed': true,
    'closureCriticalModuleCount': 1,
    'closureReviewConfirmedByUid': 'si-1',
    'closureReviewConfirmedByName': 'Senior Inspector',
    'closureReviewConfirmedAt': confirmationTime,
    'publishedByUid': 'admin-1',
    'publishedByName': 'Admin One',
    'publishedAt': '2026-08-09T11:00:00.000Z',
  };
}

Map<String, dynamic> _validAudit() => <String, dynamic>{
  'firestoreId': 'audit-1',
  'packageFirestoreId': 'package-1',
  'versionFirestoreId': 'version-1',
  'action': 'published',
  'performedByUid': 'admin-1',
  'performedByName': 'Admin One',
  'performedAt': '2026-08-09T11:00:00.000Z',
  'updatedAt': '2026-08-09T11:00:00.000Z',
  'reason': null,
  'beforeHash': null,
  'afterHash': _contentHash,
  'payloadSnapshotJson': '{"firestoreId":"version-1"}',
  'metadataJson': '{"source":"publisher"}',
  'version': 1,
  'schemaVersion': 1,
  'isDeleted': false,
};

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);
