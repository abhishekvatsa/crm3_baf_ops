import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_active_version_refresh_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/template_active_version_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Isar db;
  late Directory directory;
  late IsarTemplateGovernanceRepository repo;
  late _Remote remote;
  late AppUser? actor;
  late TemplateActiveVersionRefresh service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'active_version_refresh_',
    );
    db = await Isar.open(
      [
        TemplatePackageSchema,
        TemplateVersionSchema,
        TemplatePublishAuditSchema,
      ],
      directory: directory.path,
      inspector: false,
    );
    app.isar = db;
    repo = IsarTemplateGovernanceRepository();
    remote = _Remote();
    actor = _actor;
    service = TemplateActiveVersionRefresh(
      actor: () => actor,
      remote: remote,
      localPackages: repo.getAllPackages,
      localVersion: repo.getVersionByFirestoreId,
      localAudits: repo.getAuditsForVersion,
      apply: (version, admission) =>
          repo.applyVersionFromRemote(version, beforeApply: admission),
    );
    await db.writeTxn(() async {
      await db.templatePackages.put(_package());
      await db.templatePublishAudits.put(_audit());
      // Saved unpublished work and a successor must never be replaced.
      await db.templateVersions.put(
        _version('saved-draft')
          ..isSynced = false
          ..status = TemplateVersionStatus.draft,
      );
      await db.templateVersions.put(_version('successor'));
    });
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    final target = directory.resolveSymbolicLinksSync();
    final temp = Directory.systemTemp.resolveSymbolicLinksSync();
    if (!target.startsWith(
      '$temp${Platform.pathSeparator}active_version_refresh_',
    )) {
      throw StateError('Unexpected test cleanup target');
    }
    await directory.delete(recursive: true);
  });

  Future<void> refresh() async {
    expect(
      (await service.refresh(
        packageId: 'package',
        versionId: 'old-active',
      )).isReady,
      isTrue,
    );
  }

  test(
    'exact old pointer outside latest100 repairs only missing native row and converges',
    () async {
      // The fake authenticated server holds 101 newer records. Exact lookup is
      // required; no latest-record query or cursor reset exists in this interface.
      for (var n = 0; n < 101; n++) {
        remote.versions['new-$n'] = _version('new-$n')
          ..updatedAt = DateTime.utc(2026, 10, 1);
      }
      final before = {
        for (final row in await db.templateVersions.where().findAll())
          row.firestoreId!: (row.id, jsonEncode(row.toMap()), row.isSynced),
      };
      final packageBefore = jsonEncode(
        (await repo.getPackageByFirestoreId('package'))!.toMap(),
      );
      final auditBefore = jsonEncode(
        (await repo.getAuditsForVersion('old-active')).single.toMap(),
      );
      await refresh();
      await refresh();
      expect(remote.versionReads, ['old-active', 'old-active']);
      expect(await db.templateVersions.count(), 3);
      for (final entry in before.entries) {
        final row = (await repo.getVersionByFirestoreId(entry.key))!;
        expect((row.id, jsonEncode(row.toMap()), row.isSynced), entry.value);
      }
      expect(
        jsonEncode((await repo.getPackageByFirestoreId('package'))!.toMap()),
        packageBefore,
      );
      expect(
        jsonEncode(
          (await repo.getAuditsForVersion('old-active')).single.toMap(),
        ),
        auditBefore,
      );
    },
  );

  for (final failure in [
    'denied',
    'offline',
    'actor-during-read',
    'remote-pointer',
    'pointer-reread',
    'invalid-hash',
    'audit-mismatch',
    'wrong-package',
    'missing-local-audit',
    'dirty-package',
    'dirty-version',
    'different-version',
    'different-instant',
    'duplicate-version',
    'duplicate-package',
  ]) {
    test('$failure preserves all original native records', () async {
      if (failure == 'denied') actor = null;
      if (failure == 'offline') remote.failRead = true;
      if (failure == 'actor-during-read') {
        remote.afterVersion = () {
          actor = _otherActor;
        };
      }
      if (failure == 'remote-pointer') {
        remote.packageRecord.activeVersionFirestoreId = 'successor';
      }
      if (failure == 'pointer-reread') remote.changePointerOnReread = true;
      if (failure == 'invalid-hash') {
        remote.versions['old-active']!.jobTemplateSnapshotJson =
            '{"changed":true}';
      }
      if (failure == 'audit-mismatch') {
        remote.auditRecord.afterHash = '0' * 64;
      }
      if (failure == 'wrong-package') {
        remote.versions['old-active']!.packageFirestoreId = 'other';
      }
      await db.writeTxn(() async {
        if (failure == 'missing-local-audit') {
          await db.templatePublishAudits.clear();
        }
        if (failure == 'dirty-package') {
          final row = (await repo.getPackageByFirestoreId('package'))!
            ..isSynced = false;
          await db.templatePackages.put(row);
        }
        if (failure == 'dirty-version') {
          await db.templateVersions.put(
            _version('old-active')..isSynced = false,
          );
        }
        if (failure == 'different-version') {
          await db.templateVersions.put(
            _version('old-active')..releaseNotes = 'different retained payload',
          );
        }
        if (failure == 'different-instant') {
          await db.templateVersions.put(
            _version('old-active')
              ..updatedAt = _time.add(const Duration(microseconds: 1)),
          );
        }
        if (failure == 'duplicate-version') {
          await db.templateVersions.put(_version('old-active'));
          await db.templateVersions.put(_version('old-active'));
        }
        if (failure == 'duplicate-package') {
          await db.templatePackages.put(_package());
        }
      });
      final before = await _nativeSnapshot(db);
      await expectLater(refresh(), throwsA(anything));
      expect(await _nativeSnapshot(db), before);
    });
  }

  for (final change in ['actor', 'pointer', 'audit']) {
    test(
      '$change while waiting for native transaction blocks insertion',
      () async {
        final blocked = Completer<void>();
        final release = Completer<void>();
        service = TemplateActiveVersionRefresh(
          actor: () => actor,
          remote: remote,
          localPackages: repo.getAllPackages,
          localVersion: repo.getVersionByFirestoreId,
          localAudits: repo.getAuditsForVersion,
          apply: (version, admission) async {
            final transaction = db.writeTxn(() async {
              blocked.complete();
              await release.future;
              if (change == 'pointer') {
                final row = (await repo.getPackageByFirestoreId('package'))!
                  ..activeVersionFirestoreId = 'successor';
                await db.templatePackages.put(row);
              }
              if (change == 'audit') await db.templatePublishAudits.clear();
            });
            await blocked.future;
            final queued = repo.applyVersionFromRemote(
              version,
              beforeApply: admission,
            );
            if (change == 'actor') actor = _otherActor;
            release.complete();
            await transaction;
            return queued;
          },
        );
        await expectLater(
          refresh(),
          throwsA(isA<TemplateActiveVersionRefreshException>()),
        );
        expect(await repo.getVersionByFirestoreId('old-active'), isNull);
        expect(await db.templateVersions.count(), 2);
      },
    );
  }

  test('session loss after awaited native put rolls insertion back', () async {
    var checks = 0;
    await expectLater(
      repo.applyVersionFromRemote(
        _version('old-active'),
        beforeApply: () async {
          checks++;
          if (checks == 3) {
            // This admission invocation is after the actual native put.
            expect(await repo.getVersionByFirestoreId('old-active'), isNotNull);
            throw const TemplateActiveVersionRefreshException(
              'Session changed',
            );
          }
        },
      ),
      throwsA(isA<TemplateActiveVersionRefreshException>()),
    );
    expect(checks, 3);
    expect(await repo.getVersionByFirestoreId('old-active'), isNull);
  });

  for (final state in [
    (false, false, false),
    (true, true, false),
    (true, false, true),
  ]) {
    test('server snapshot $state is not authority', () {
      expect(
        () => requireConfirmedTemplateRefreshSnapshot(
          exists: state.$1,
          isFromCache: state.$2,
          hasPendingWrites: state.$3,
        ),
        throwsA(isA<TemplateActiveVersionRefreshException>()),
      );
    });
  }
  test(
    'actor authority rejects loading/error/unapproved and credential mismatch',
    () {
      expect(verifiedTemplateRefreshActor(const AsyncLoading(), 'si'), isNull);
      expect(
        verifiedTemplateRefreshActor(
          AsyncError(StateError('profile'), StackTrace.current),
          'si',
        ),
        isNull,
      );
      expect(verifiedTemplateRefreshActor(AsyncData(_actor), 'other'), isNull);
      expect(
        verifiedTemplateRefreshActor(
          AsyncData(
            AppUser(
              uid: 'si',
              name: 'SI',
              email: 'si@example.invalid',
              roles: [AppRole.si],
              isApproved: false,
              createdAt: DateTime.utc(2026),
            ),
          ),
          'si',
        ),
        isNull,
      );
      expect(verifiedTemplateRefreshActor(AsyncData(_actor), 'si')?.uid, 'si');
    },
  );
}

Future<String> _nativeSnapshot(Isar db) async => jsonEncode({
  'packages': [
    for (final r in await db.templatePackages.where().findAll())
      [r.id, r.isSynced, r.toMap()],
  ],
  'versions': [
    for (final r in await db.templateVersions.where().findAll())
      [r.id, r.isSynced, r.toMap()],
  ],
  'audits': [
    for (final r in await db.templatePublishAudits.where().findAll())
      [r.id, r.isSynced, r.toMap()],
  ],
});

class _Remote implements TemplateActiveVersionRemoteReader {
  final packageRecord = _package();
  final versions = {'old-active': _version('old-active')};
  final auditRecord = _audit();
  final versionReads = <String>[];
  bool failRead = false;
  bool changePointerOnReread = false;
  int packageReads = 0;
  void Function()? afterVersion;
  @override
  Future<TemplatePackage> package(String id) async {
    if (failRead) throw StateError('Offline');
    packageReads++;
    if (changePointerOnReread && packageReads == 2) {
      packageRecord.activeVersionFirestoreId = 'successor';
    }
    return TemplatePackage.fromMap(packageRecord.toMap(), id);
  }

  @override
  Future<TemplateVersion> version(String id) async {
    versionReads.add(id);
    afterVersion?.call();
    return TemplateVersion.fromMap(versions[id]!.toMap(), id);
  }

  @override
  Future<List<TemplatePublishAudit>> audits(String versionId) async => [
    TemplatePublishAudit.fromMap(auditRecord.toMap(), auditRecord.firestoreId!),
  ];
}

final _actor = AppUser(
  uid: 'si',
  name: 'SI',
  email: 'si@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
final _otherActor = AppUser(
  uid: 'other',
  name: 'Other',
  email: 'other@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
final _time = DateTime.utc(2026, 6, 1);
TemplatePackage _package() => TemplatePackage()
  ..firestoreId = 'package'
  ..packageCode = 'TEST'
  ..title = 'Retained package'
  ..activeVersionFirestoreId = 'old-active'
  ..latestVersionNumber = 1
  ..createdByUid = 'si'
  ..updatedByUid = 'si'
  ..createdAt = _time
  ..updatedAt = _time
  ..isSynced = true;
TemplateVersion _version(String id) {
  final record = TemplateVersion()
    ..firestoreId = id
    ..packageFirestoreId = 'package'
    ..status = TemplateVersionStatus.published
    ..versionNumber = 1
    ..jobTemplateSnapshotJson = '{"title":"Retained work"}'
    ..createdByUid = 'si'
    ..updatedByUid = 'si'
    ..publishedByUid = 'si'
    ..createdAt = _time
    ..updatedAt = _time
    ..publishedAt = _time
    ..isSynced = true;
  record.refreshContentHash();
  return record;
}

TemplatePublishAudit _audit() => TemplatePublishAudit()
  ..firestoreId = 'audit'
  ..packageFirestoreId = 'package'
  ..versionFirestoreId = 'old-active'
  ..action = TemplatePublishAuditAction.published
  ..performedByUid = 'si'
  ..performedAt = _time
  ..updatedAt = _time
  ..afterHash = _version('old-active').contentHash
  ..payloadSnapshotJson = jsonEncode(_version('old-active').toMap())
  ..isSynced = true;
