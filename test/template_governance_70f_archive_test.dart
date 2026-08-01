import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

Future<void> _withTemplateGovernanceIsar(
  Future<void> Function(Isar isar, IsarTemplateGovernanceRepository repository)
  body,
) async {
  final directory = await Directory.systemTemp.createTemp('baf_70f_archive_');
  final instance = await Isar.open(
    [TemplatePackageSchema, TemplateVersionSchema, TemplatePublishAuditSchema],
    directory: directory.path,
    name: 'baf_70f_archive_${DateTime.now().microsecondsSinceEpoch}',
  );
  app.isar = instance;

  var auditSequence = 0;
  final repository = IsarTemplateGovernanceRepository(
    auditFirestoreIdFactory: () => 'audit-70f-${++auditSequence}',
  );

  try {
    await body(instance, repository);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

AppUser _actor(AppRole role, {String? uid}) => AppUser(
  uid: uid ?? 'user-${role.name}',
  name: 'User ${uid ?? role.name}',
  email: '${uid ?? role.name}@test.local',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026, 6, 14),
);

TemplateVersion _draft({String firestoreId = 'draft-70f'}) {
  return TemplateVersion()
    ..firestoreId = firestoreId
    ..packageFirestoreId = 'pkg-70f'
    ..versionNumber = 3
    ..versionLabel = 'v3 working draft'
    ..status = TemplateVersionStatus.draft
    ..jobTemplateSnapshotJson = '{"title":"BAF draft"}'
    ..moduleSnapshotsJson = '[{"moduleCode":"GAS-01"}]'
    ..fieldDefinitionsJson = '[{"key":"leakTight"}]'
    ..checklistJson = '[{"id":"confirm"}]'
    ..targetRefs = ['furnace:1']
    ..safetyClass = 'gasCritical';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestIsarCore();
  });

  group('70F governed TemplateVersion draft archive', () {
    test(
      'archives atomically, preserves payload, and writes audit evidence',
      () async {
        await _withTemplateGovernanceIsar((isar, repository) async {
          final actor = _actor(AppRole.si);
          final draft = _draft();
          final originalPayload = <String>[
            draft.jobTemplateSnapshotJson,
            draft.moduleSnapshotsJson,
            draft.fieldDefinitionsJson,
            draft.checklistJson,
          ];

          await repository.saveVersion(draft, actor: actor);
          await repository.archiveDraftVersion(
            draft,
            actor: actor,
            reason: 'Abandoned duplicate authoring path.',
          );

          final archived = await repository.getVersionByFirestoreId(
            'draft-70f',
          );
          expect(archived, isNotNull);
          expect(archived!.status, TemplateVersionStatus.archived);
          expect(archived.isDeleted, isFalse);
          expect(archived.isSynced, isFalse);
          expect(archived.contentHash, startsWith('tg2-sha256:'));
          expect(<String>[
            archived.jobTemplateSnapshotJson,
            archived.moduleSnapshotsJson,
            archived.fieldDefinitionsJson,
            archived.checklistJson,
          ], originalPayload);

          final audits = await repository.getAuditsForVersion('draft-70f');
          expect(audits, hasLength(1));
          final audit = audits.single;
          expect(audit.firestoreId, 'audit-70f-1');
          expect(audit.action, TemplatePublishAuditAction.archived);
          expect(audit.reason, 'Abandoned duplicate authoring path.');
          expect(audit.afterHash, archived.contentHash);
          expect(audit.isSynced, isFalse);

          final snapshot = jsonDecode(audit.payloadSnapshotJson!);
          expect(snapshot, isA<Map<String, dynamic>>());
          expect((snapshot as Map<String, dynamic>)['status'], 'archived');
          expect(snapshot['isDeleted'], isFalse);

          final packageVersions = await repository.getVersionsForPackage(
            'pkg-70f',
          );
          expect(packageVersions.where((version) => version.isDraft), isEmpty);
          expect(
            await isar.templateVersions.get(archived.id),
            isNotNull,
            reason:
                'archive must retain the same governed identity for recovery',
          );
        });
      },
    );

    test(
      'restores the same archived draft identity after archive sync',
      () async {
        await _withTemplateGovernanceIsar((isar, repository) async {
          final actor = _actor(AppRole.si);
          final draft = _draft(firestoreId: 'draft-restore-70f');
          await repository.saveVersion(draft, actor: actor);
          final originalId = draft.id;

          await repository.archiveDraftVersion(
            draft,
            actor: actor,
            reason: 'Draft archived after duplicate authoring review.',
          );
          await repository.markVersionsSynced([draft.id]);
          final archived = await repository.getVersionByFirestoreId(
            'draft-restore-70f',
          );
          expect(archived, isNotNull);
          expect(archived!.isArchivedDraft, isTrue);
          expect(archived.isSynced, isTrue);

          await expectLater(
            repository.restoreArchivedDraftVersion(
              archived,
              actor: actor,
              reason: 'Draft restored before archive audit synchronization.',
            ),
            throwsStateError,
          );

          final archiveAudits = await repository.getAuditsForVersion(
            'draft-restore-70f',
          );
          expect(archiveAudits, hasLength(1));
          await repository.markAuditsSynced([archiveAudits.single.id]);

          await repository.restoreArchivedDraftVersion(
            archived,
            actor: actor,
            reason: 'Draft restored because the review decision changed.',
          );

          final restored = await repository.getVersionByFirestoreId(
            'draft-restore-70f',
          );
          expect(restored, isNotNull);
          expect(restored!.id, originalId);
          expect(restored.firestoreId, 'draft-restore-70f');
          expect(restored.isDraft, isTrue);
          expect(restored.isDeleted, isFalse);
          expect(restored.isSynced, isFalse);

          final audits = await repository.getAuditsForVersion(
            'draft-restore-70f',
          );
          expect(audits, hasLength(2));
          final restoredAudit = audits.firstWhere(
            (audit) => audit.action == TemplatePublishAuditAction.restored,
          );
          expect(
            restoredAudit.reason,
            'Draft restored because the review decision changed.',
          );
          expect(restoredAudit.firestoreId, 'audit-70f-2');
          final payload =
              jsonDecode(restoredAudit.payloadSnapshotJson!)
                  as Map<String, dynamic>;
          expect(payload['status'], 'draft');
          expect(payload['firestoreId'], 'draft-restore-70f');

          final activeDrafts =
              (await repository.getVersionsForPackage(
                'pkg-70f',
              )).where((version) => version.isDraft).toList();
          expect(activeDrafts.map((version) => version.firestoreId), [
            'draft-restore-70f',
          ]);
        });
      },
    );

    test('unsynced draft can only be archived by its creator', () async {
      await _withTemplateGovernanceIsar((isar, repository) async {
        final creator = _actor(AppRole.si, uid: 'creator-si');
        final otherGovernor = _actor(AppRole.si, uid: 'other-si');
        final draft = _draft(firestoreId: 'creator-owned-unsynced');
        await repository.saveVersion(draft, actor: creator);

        await expectLater(
          repository.archiveDraftVersion(
            draft,
            actor: otherGovernor,
            reason: 'Other governor attempted offline draft archive.',
          ),
          throwsStateError,
        );

        final reloaded = await repository.getVersionByFirestoreId(
          'creator-owned-unsynced',
        );
        expect(reloaded, isNotNull);
        expect(reloaded!.isDraft, isTrue);
      });
    });

    test(
      'restored draft waits for its restore audit before further mutation',
      () async {
        await _withTemplateGovernanceIsar((isar, repository) async {
          final actor = _actor(AppRole.si);
          final draft = _draft(firestoreId: 'draft-restore-guard-70f');
          await repository.saveVersion(draft, actor: actor);
          await repository.archiveDraftVersion(
            draft,
            actor: actor,
            reason: 'Draft archived before controlled restore verification.',
          );
          await repository.markVersionsSynced([draft.id]);
          final archiveAudit =
              (await repository.getAuditsForVersion(
                'draft-restore-guard-70f',
              )).single;
          await repository.markAuditsSynced([archiveAudit.id]);

          final archived = await repository.getVersionByFirestoreId(
            'draft-restore-guard-70f',
          );
          expect(archived, isNotNull);
          await repository.restoreArchivedDraftVersion(
            archived!,
            actor: actor,
            reason: 'Draft restored for controlled lifecycle verification.',
          );
          await repository.markVersionsSynced([archived.id]);

          final restored = await repository.getVersionByFirestoreId(
            'draft-restore-guard-70f',
          );
          expect(restored, isNotNull);
          expect(restored!.isDraft, isTrue);
          expect(restored.isSynced, isTrue);
          final restoredAudit = (await repository.getAuditsForVersion(
            'draft-restore-guard-70f',
          )).firstWhere(
            (audit) => audit.action == TemplatePublishAuditAction.restored,
          );
          expect(restoredAudit.isSynced, isFalse);

          for (final operation in <Future<void> Function()>[
            () => repository.saveVersion(restored, actor: actor),
            () => repository.archiveDraftVersion(
              restored,
              actor: actor,
              reason: 'Second archive must wait for restored audit sync.',
            ),
            () => repository.publishVersion(
              restored,
              actor: actor,
              reason: 'Publish must wait for restored audit sync.',
            ),
          ]) {
            await expectLater(
              operation(),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  contains('restored-draft audit'),
                ),
              ),
            );
          }

          await repository.markAuditsSynced([restoredAudit.id]);
          await repository.saveVersion(restored, actor: actor);
          expect(restored.isSynced, isFalse);
        });
      },
    );

    test('generic draft save cannot resurrect an archived identity', () async {
      await _withTemplateGovernanceIsar((isar, repository) async {
        final actor = _actor(AppRole.si);
        final draft = _draft(firestoreId: 'draft-no-resurrection-70f');
        await repository.saveVersion(draft, actor: actor);
        await repository.archiveDraftVersion(
          draft,
          actor: actor,
          reason: 'Archive identity must not be restored by generic save.',
        );

        final archived = await repository.getVersionByFirestoreId(
          'draft-no-resurrection-70f',
        );
        expect(archived, isNotNull);
        final staleDraft = TemplateVersion.fromMap(
          archived!.toMap(),
          archived.firestoreId!,
        )..status = TemplateVersionStatus.draft;

        await expectLater(
          repository.saveVersion(staleDraft, actor: actor),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Only active draft TemplateVersions can be saved'),
            ),
          ),
        );
        expect(
          (await repository.getVersionByFirestoreId(
            'draft-no-resurrection-70f',
          ))!.isArchivedDraft,
          isTrue,
        );
      });
    });

    test(
      'requires a reason and refuses non-draft or unauthorized archive',
      () async {
        await _withTemplateGovernanceIsar((isar, repository) async {
          final si = _actor(AppRole.si);
          final draft = _draft();
          await repository.saveVersion(draft, actor: si);

          await expectLater(
            repository.archiveDraftVersion(draft, actor: si, reason: 'short'),
            throwsStateError,
          );
          expect(
            (await repository.getVersionByFirestoreId('draft-70f'))!.isDraft,
            isTrue,
          );

          await expectLater(
            repository.archiveDraftVersion(
              draft,
              actor: _actor(AppRole.operations),
              reason: 'Operations cannot archive governed drafts.',
            ),
            throwsStateError,
          );

          draft
            ..status = TemplateVersionStatus.published
            ..isSynced = true
            ..refreshContentHash();
          await isar.writeTxn(() => isar.templateVersions.put(draft));

          await expectLater(
            repository.archiveDraftVersion(
              draft,
              actor: si,
              reason: 'Published records must remain immutable.',
            ),
            throwsStateError,
          );
        });
      },
    );

    test(
      'publish-audit tombstones apply without overwriting fresher evidence',
      () async {
        await _withTemplateGovernanceIsar((isar, repository) async {
          final firstSeen = DateTime.utc(2026, 7, 25, 10);
          final serverDelete = DateTime.utc(2026, 7, 25, 11);
          final existing =
              TemplatePublishAudit()
                ..firestoreId = 'audit-server-delete'
                ..versionFirestoreId = 'version-server-delete'
                ..performedAt = firstSeen
                ..updatedAt = firstSeen
                ..isSynced = true;
          await repository.insertAuditFromRemote(existing);

          final tombstone =
              TemplatePublishAudit()
                ..firestoreId = existing.firestoreId
                ..versionFirestoreId = existing.versionFirestoreId
                ..performedAt = firstSeen
                ..updatedAt = serverDelete
                ..version = 2
                ..isDeleted = true
                ..isSynced = true;
          final applied = await repository.applyTombstoneFromAuditRemote(
            tombstone,
          );

          expect(applied.outcome, RemoteTombstoneApplyOutcome.applied);
          expect(
            (await repository.getAuditByFirestoreId(
              'audit-server-delete',
            ))!.isDeleted,
            isTrue,
          );
          expect(
            await repository.getAuditsForVersion('version-server-delete'),
            isEmpty,
          );

          final dirty =
              TemplatePublishAudit()
                ..firestoreId = 'audit-dirty'
                ..versionFirestoreId = 'version-dirty'
                ..performedAt = firstSeen
                ..updatedAt = serverDelete.add(const Duration(hours: 1))
                ..isSynced = false;
          await isar.writeTxn(() => isar.templatePublishAudits.put(dirty));
          final staleTombstone =
              TemplatePublishAudit()
                ..firestoreId = dirty.firestoreId
                ..versionFirestoreId = dirty.versionFirestoreId
                ..performedAt = firstSeen
                ..updatedAt = serverDelete
                ..isDeleted = true
                ..isSynced = true;

          final preserved = await repository.applyTombstoneFromAuditRemote(
            staleTombstone,
          );
          expect(
            preserved.outcome,
            RemoteTombstoneApplyOutcome.localDirtyPreserved,
          );
          expect(
            (await repository.getAuditByFirestoreId('audit-dirty'))!.isDeleted,
            isFalse,
          );

          final missing = await repository.applyTombstoneFromAuditRemote(
            TemplatePublishAudit()
              ..firestoreId = 'audit-missing'
              ..versionFirestoreId = 'version-missing'
              ..performedAt = firstSeen
              ..updatedAt = serverDelete
              ..isDeleted = true,
          );
          expect(missing.outcome, RemoteTombstoneApplyOutcome.localMissing);
          expect(
            await repository.getAuditByFirestoreId('audit-missing'),
            isNull,
          );
        });
      },
    );
  });
}
