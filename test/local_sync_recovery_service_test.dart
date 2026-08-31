import 'dart:io';

import 'package:crm3_baf_ops/core/services/local_sync_recovery_service.dart';
import 'package:crm3_baf_ops/core/services/sync_rejection_service.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test('unapproved recovery is rejected before database access', () async {
    var lookups = 0;
    final service = LocalSyncRecoveryService(
      databaseLookup: () {
        lookups++;
        return null;
      },
      authenticatedUidLookup: () => 'operator-1',
    );

    await expectLater(
      service.discardOwnRejectedChanges(actor: _actor(approved: false)),
      throwsStateError,
    );
    expect(lookups, 0);
  });

  test(
    'a changed authenticated account fails before database access',
    () async {
      var lookups = 0;
      final service = LocalSyncRecoveryService(
        databaseLookup: () {
          lookups++;
          return null;
        },
        authenticatedUidLookup: () => 'another-user',
      );

      await expectLater(
        service.discardOwnRejectedChanges(actor: _actor()),
        throwsStateError,
      );
      expect(lookups, 0);
    },
  );

  test(
    'owned rejected edits are replaced by exact authoritative server data',
    () async {
      await _withDatabase((database) async {
        final local = _directive(version: 4, isSynced: false);
        await _insert(database, local, _rejection());
        final remote =
            _directive(version: 5, isSynced: true)
              ..title = 'Authoritative operations instruction'
              ..updatedAt = DateTime.utc(2026, 8, 25, 11);
        final service = _service(
          database,
          reader:
              (collection, identifier) async =>
                  LocalSyncRecoveryRemoteDocument.existing(remote.toMap()),
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());
        final restored = await database.operationalDirectives.get(local.id);
        final rejection = await database.syncRejections.where().findFirst();

        expect(result.restoredFromServer, 1);
        expect(result.removedLocalOnly, 0);
        expect(restored!.id, local.id);
        expect(restored.version, 5);
        expect(restored.title, remote.title);
        expect(restored.isSynced, isTrue);
        expect(rejection!.isResolved, isTrue);
        expect(rejection.resolvedByUid, 'operator-1');
      });
    },
  );

  test(
    'an owned rejected record absent from the server is removed locally',
    () async {
      await _withDatabase((database) async {
        final local = _directive(isSynced: false);
        await _insert(database, local, _rejection());
        final service = _service(
          database,
          reader:
              (_, _) async => const LocalSyncRecoveryRemoteDocument.missing(),
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());

        expect(result.removedLocalOnly, 1);
        expect(await database.operationalDirectives.get(local.id), isNull);
        expect(
          (await database.syncRejections.where().findFirst())!.isResolved,
          isTrue,
        );
      });
    },
  );

  test('another user cannot discard an owned pending change', () async {
    await _withDatabase((database) async {
      final local = _directive(ownerUid: 'other-operator', isSynced: false);
      await _insert(database, local, _rejection());
      var remoteReads = 0;
      final service = _service(
        database,
        reader: (_, _) async {
          remoteReads++;
          return const LocalSyncRecoveryRemoteDocument.missing();
        },
      );

      final result = await service.discardOwnRejectedChanges(actor: _actor());

      expect(result.preservedOtherUser, 1);
      expect(remoteReads, 0);
      expect(await database.operationalDirectives.get(local.id), isNotNull);
      expect(
        (await database.syncRejections.where().findFirst())!.isResolved,
        isFalse,
      );
    });
  });

  test('legacy rejection without user provenance fails closed', () async {
    await _withDatabase((database) async {
      final local = _directive(isSynced: false);
      await _insert(database, local, _rejection()..originatingUid = null);
      var remoteReads = 0;
      final service = _service(
        database,
        reader: (_, _) async {
          remoteReads++;
          return const LocalSyncRecoveryRemoteDocument.missing();
        },
      );

      final result = await service.discardOwnRejectedChanges(actor: _actor());

      expect(result.preservedOtherUser, 1);
      expect(remoteReads, 0);
      expect(await database.operationalDirectives.get(local.id), isNotNull);
    });
  });

  test(
    'another users rejection cannot authorize current-user recovery',
    () async {
      await _withDatabase((database) async {
        final local = _directive(isSynced: false);
        await _insert(
          database,
          local,
          _rejection()..originatingUid = 'another-user',
        );
        var remoteReads = 0;
        final service = _service(
          database,
          reader: (_, _) async {
            remoteReads++;
            return const LocalSyncRecoveryRemoteDocument.missing();
          },
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());

        expect(result.preservedOtherUser, 1);
        expect(remoteReads, 0);
        expect(await database.operationalDirectives.get(local.id), isNotNull);
      });
    },
  );

  test(
    'transient rejections and immutable evidence remain untouched',
    () async {
      await _withDatabase((database) async {
        final local = _directive(isSynced: false);
        await _insert(database, local, _rejection(permanent: false));
        final immutable =
            _rejection()
              ..entityType = 'audit_event'
              ..entityId = 'audit-1'
              ..firestoreId = 'audit-1';
        await database.writeTxn(() => database.syncRejections.put(immutable));
        var reads = 0;
        final service = _service(
          database,
          reader: (_, _) async {
            reads++;
            return const LocalSyncRecoveryRemoteDocument.missing();
          },
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());

        expect(result.preservedUnsupported, 1);
        expect(result.recoveredCount, 0);
        expect(reads, 0);
        expect(await database.operationalDirectives.get(local.id), isNotNull);
        expect(
          await database.syncRejections
              .filter()
              .isResolvedEqualTo(false)
              .count(),
          2,
        );
      });
    },
  );

  test('server read failure never deletes the device record', () async {
    await _withDatabase((database) async {
      final local = _directive(isSynced: false);
      await _insert(database, local, _rejection());
      final service = _service(
        database,
        reader: (_, _) async => throw StateError('network unavailable'),
      );

      final result = await service.discardOwnRejectedChanges(actor: _actor());

      expect(result.preservedFailed, 1);
      expect(result.errors.single, contains('network unavailable'));
      expect(await database.operationalDirectives.get(local.id), isNotNull);
      expect(
        (await database.syncRejections.where().findFirst())!.isResolved,
        isFalse,
      );
    });
  });

  test(
    'malformed authoritative records cannot overwrite valid local evidence',
    () async {
      await _withDatabase((database) async {
        final local = _directive(isSynced: false);
        await _insert(database, local, _rejection());
        final service = _service(
          database,
          reader:
              (_, _) async => const LocalSyncRecoveryRemoteDocument.existing(
                <String, dynamic>{},
              ),
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());

        expect(result.preservedFailed, 1);
        expect(await database.operationalDirectives.get(local.id), isNotNull);
      });
    },
  );

  test('concurrent account changes fail without deleting local data', () async {
    await _withDatabase((database) async {
      final local = _directive(isSynced: false);
      await _insert(database, local, _rejection());
      var signedInUid = 'operator-1';
      final service = LocalSyncRecoveryService(
        databaseLookup: () => database,
        authenticatedUidLookup: () => signedInUid,
        remoteReader: (_, _) async {
          signedInUid = 'different-user';
          return const LocalSyncRecoveryRemoteDocument.missing();
        },
      );

      final result = await service.discardOwnRejectedChanges(actor: _actor());

      expect(result.preservedFailed, 1);
      expect(await database.operationalDirectives.get(local.id), isNotNull);
      expect(
        (await database.syncRejections.where().findFirst())!.isResolved,
        isFalse,
      );
    });
  });

  test(
    'concurrent local edits are never overwritten by recovery readback',
    () async {
      await _withDatabase((database) async {
        final local = _directive(isSynced: false);
        await _insert(database, local, _rejection());
        final service = _service(
          database,
          reader: (_, _) async {
            await database.writeTxn(() async {
              final current = await database.operationalDirectives.get(
                local.id,
              );
              current!.version += 1;
              current.title = 'Newer protected operator edit';
              await database.operationalDirectives.put(current);
            });
            return const LocalSyncRecoveryRemoteDocument.missing();
          },
        );

        final result = await service.discardOwnRejectedChanges(actor: _actor());
        final retained = await database.operationalDirectives.get(local.id);

        expect(result.preservedFailed, 1);
        expect(retained!.title, 'Newer protected operator edit');
        expect(
          (await database.syncRejections.where().findFirst())!.isResolved,
          isFalse,
        );
      });
    },
  );

  test(
    'permanent-rejection count includes records outside the recent preview',
    () async {
      await _withDatabase((database) async {
        await database.writeTxn(() async {
          for (var index = 0; index < 8; index++) {
            final rejection =
                _rejection()
                  ..entityId = 'directive-$index'
                  ..firestoreId = 'directive-$index';
            await database.syncRejections.put(rejection);
          }
        });

        final service = SyncRejectionService(databaseLookup: () => database);

        expect(
          await service.watchRecent(limit: recentSyncRejectionLimit).first,
          hasLength(5),
        );
        expect(await service.watchUnresolvedPermanentCount().first, 8);
      });
    },
  );

  test(
    'authenticated purge receipt removes only the exact clean tombstone',
    () async {
      await _withDatabase((database) async {
        final local = _directive(version: 4, isSynced: true)..isDeleted = true;
        await database.writeTxn(
          () => database.operationalDirectives.put(local),
        );
        final service = LocalSyncRecoveryService(
          databaseLookup: () => database,
          authenticatedUidLookup: () => 'admin-1',
        );

        final removed = await service.removeAuthoritativelyPurgedTombstone(
          actor: _adminActor(),
          receipt: _purgeReceipt(version: 4),
          collectionId: 'directives',
          documentId: 'directive-1',
        );

        expect(removed, isTrue);
        expect(await database.operationalDirectives.get(local.id), isNull);
      });
    },
  );

  test(
    'server purge manifest removes the exact clean tombstone for every approved user',
    () async {
      await _withDatabase((database) async {
        final local = _directive(version: 4, isSynced: true)..isDeleted = true;
        await database.writeTxn(
          () => database.operationalDirectives.put(local),
        );
        final service = LocalSyncRecoveryService(
          databaseLookup: () => database,
          authenticatedUidLookup: () => 'operator-1',
          purgeManifestReader:
              (_) async => const <AuthoritativePurgeManifest>[
                AuthoritativePurgeManifest(
                  collectionId: 'directives',
                  documentId: 'directive-1',
                  sourceVersion: 4,
                ),
              ],
        );

        final result = await service.reconcileAuthoritativelyPurgedTombstones(
          actor: _actor(),
        );

        expect(result.removed, 1);
        expect(result.preserved, 0);
        expect(await database.operationalDirectives.get(local.id), isNull);
      });
    },
  );

  test(
    'purge reconciliation performs no server read without local tombstones',
    () async {
      await _withDatabase((database) async {
        var reads = 0;
        final service = LocalSyncRecoveryService(
          databaseLookup: () => database,
          authenticatedUidLookup: () => 'operator-1',
          purgeManifestReader: (candidates) async {
            reads += candidates.length;
            return const <AuthoritativePurgeManifest>[];
          },
        );

        final result = await service.reconcileAuthoritativelyPurgedTombstones(
          actor: _actor(),
        );

        expect(reads, 0);
        expect(result.removed, 0);
        expect(result.preserved, 0);
      });
    },
  );

  test(
    'purge reconciliation never queries or removes dirty local evidence',
    () async {
      await _withDatabase((database) async {
        final local = _directive(version: 5, isSynced: false)..isDeleted = true;
        await database.writeTxn(
          () => database.operationalDirectives.put(local),
        );
        var manifestReads = 0;
        final service = LocalSyncRecoveryService(
          databaseLookup: () => database,
          authenticatedUidLookup: () => 'operator-1',
          purgeManifestReader: (candidates) async {
            manifestReads += candidates.length;
            return const <AuthoritativePurgeManifest>[
              AuthoritativePurgeManifest(
                collectionId: 'directives',
                documentId: 'directive-1',
                sourceVersion: 4,
              ),
            ];
          },
        );

        final result = await service.reconcileAuthoritativelyPurgedTombstones(
          actor: _actor(),
        );

        expect(result.removed, 0);
        expect(result.preserved, 0);
        expect(manifestReads, 0);
        expect(await database.operationalDirectives.get(local.id), isNotNull);
      });
    },
  );

  test('purge manifest decoder rejects extra or unsupported authority', () {
    final valid = <String, dynamic>{
      'schemaVersion': 1,
      'sourceCollection': 'directives',
      'sourceDocumentId': 'directive-1',
      'sourceVersion': 4,
      'purgedAt': '2026-08-25T12:00:00.000Z',
    };
    final manifestId = authoritativePurgeManifestId(
      'directives',
      'directive-1',
    );

    expect(
      AuthoritativePurgeManifest.fromRemote(
        valid,
        manifestId: manifestId,
      ).documentId,
      'directive-1',
    );
    expect(
      () => AuthoritativePurgeManifest.fromRemote(<String, dynamic>{
        ...valid,
        'reason': 'must remain server-only',
      }, manifestId: manifestId),
      throwsFormatException,
    );
    expect(
      () => AuthoritativePurgeManifest.fromRemote(<String, dynamic>{
        ...valid,
        'sourceCollection': 'users',
      }, manifestId: manifestId),
      throwsFormatException,
    );
    expect(
      () => AuthoritativePurgeManifest.fromRemote(<String, dynamic>{
        ...valid,
        'purgedAt': 'not-a-timestamp',
      }, manifestId: manifestId),
      throwsFormatException,
    );
    expect(
      () => AuthoritativePurgeManifest.fromRemote(
        valid,
        manifestId: 'purge_${List.filled(64, 'a').join()}',
      ),
      throwsFormatException,
    );
  });

  test('purge receipt never removes a dirty or changed local record', () async {
    await _withDatabase((database) async {
      final local = _directive(version: 5, isSynced: false)..isDeleted = true;
      await database.writeTxn(() => database.operationalDirectives.put(local));
      final service = LocalSyncRecoveryService(
        databaseLookup: () => database,
        authenticatedUidLookup: () => 'admin-1',
      );

      final removed = await service.removeAuthoritativelyPurgedTombstone(
        actor: _adminActor(),
        receipt: _purgeReceipt(version: 4),
        collectionId: 'directives',
        documentId: 'directive-1',
      );

      expect(removed, isFalse);
      expect(await database.operationalDirectives.get(local.id), isNotNull);
    });
  });

  test(
    'purge preserves a template referenced by an unsynced local diary entry',
    () async {
      await _withDatabase((database) async {
        final created = DateTime.utc(2026, 8, 25, 9);
        final template =
            JobTemplate()
              ..firestoreId = 'template-1'
              ..jobName = 'Governed maintenance template'
              ..applicableAssetType = AssetType.furnace
              ..createdAt = created
              ..updatedAt = created
              ..deletedAt = created
              ..version = 4
              ..isDeleted = true
              ..isSynced = true;
        final diary =
            JobDiaryEntry()
              ..firestoreId = 'diary-local-1'
              ..templateFirestoreId = 'template-1'
              ..note = 'Pending maintenance evidence must be retained.'
              ..createdAt = created
              ..updatedAt = created
              ..isSynced = false;
        await database.writeTxn(() async {
          await database.jobTemplates.put(template);
          await database.jobDiaryEntrys.put(diary);
        });
        final service = LocalSyncRecoveryService(
          databaseLookup: () => database,
          authenticatedUidLookup: () => 'admin-1',
        );

        final removed = await service.removeAuthoritativelyPurgedTombstone(
          actor: _adminActor(),
          receipt: _purgeReceipt(
            version: 4,
            collectionId: 'job_templates',
            documentId: 'template-1',
          ),
          collectionId: 'job_templates',
          documentId: 'template-1',
        );

        expect(removed, isFalse);
        expect(await database.jobTemplates.get(template.id), isNotNull);
        expect(await database.jobDiaryEntrys.get(diary.id), isNotNull);
      });
    },
  );
}

Future<void> _withDatabase(Future<void> Function(Isar) operation) async {
  final directory = await Directory.systemTemp.createTemp(
    'local_sync_recovery_',
  );
  final database = await Isar.open(
    [
      MaintenanceRecordSchema,
      OperationalDirectiveSchema,
      SyncRejectionSchema,
      JobTemplateSchema,
      JobExecutionSchema,
      JobModuleInstanceSchema,
      JobDiaryEntrySchema,
    ],
    directory: directory.path,
    name: 'local_sync_recovery_${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await operation(database);
  } finally {
    await database.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<void> _insert(
  Isar database,
  OperationalDirective directive,
  SyncRejection rejection,
) => database.writeTxn(() async {
  await database.operationalDirectives.put(directive);
  await database.syncRejections.put(rejection);
});

LocalSyncRecoveryService _service(
  Isar database, {
  required LocalSyncRecoveryRemoteReader reader,
}) => LocalSyncRecoveryService(
  databaseLookup: () => database,
  authenticatedUidLookup: () => 'operator-1',
  remoteReader: reader,
);

AppUser _actor({bool approved = true}) => AppUser(
  uid: 'operator-1',
  name: 'Operator One',
  email: 'operator@example.invalid',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 8, 25),
);

AppUser _adminActor() => AppUser(
  uid: 'admin-1',
  name: 'Administrator',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 25),
);

WorkflowCommandReceipt _purgeReceipt({
  required int version,
  String collectionId = 'directives',
  String documentId = 'directive-1',
}) => WorkflowCommandReceipt(
  commandId: 'purge-command-1',
  resultKey: 'pilot-record-permanently-removed',
  aggregateVersion: version,
  result: <String, Object?>{
    'collectionId': collectionId,
    'documentId': documentId,
    'purgeReceiptId': 'purge_${List.filled(64, 'a').join()}',
    'sourceDigest': List.filled(64, 'b').join(),
  },
  appliedAt: DateTime.utc(2026, 8, 25, 12),
);

OperationalDirective _directive({
  String ownerUid = 'operator-1',
  int version = 3,
  required bool isSynced,
}) {
  final created = DateTime.utc(2026, 8, 25, 9);
  return OperationalDirective()
    ..firestoreId = 'directive-1'
    ..title = 'Operations instruction'
    ..description = 'Coordinate safe equipment movement.'
    ..directedTo = AppRole.operations
    ..status = DirectiveStatus.open
    ..priority = DirectivePriority.medium
    ..createdByUid = ownerUid
    ..createdByName = 'Operator One'
    ..issuedByUid = ownerUid
    ..issuedByName = 'Operator One'
    ..issuedAt = created
    ..isActive = true
    ..isDeleted = false
    ..createdAt = created
    ..updatedAt = DateTime.utc(2026, 8, 25, 10)
    ..version = version
    ..isSynced = isSynced;
}

SyncRejection _rejection({bool permanent = true}) =>
    SyncRejection()
      ..entityType = 'directive'
      ..entityId = 'directive-1'
      ..firestoreId = 'directive-1'
      ..message = 'Rejected by the authoritative server.'
      ..originatingUid = 'operator-1'
      ..isLikelyPermanent = permanent
      ..firstSeenAt = DateTime.utc(2026, 8, 25, 10)
      ..lastSeenAt = DateTime.utc(2026, 8, 25, 10)
      ..isResolved = false;
