import 'dart:io';

import 'package:crm3_baf_ops/core/services/isar_production_recovery.dart';
import 'package:crm3_baf_ops/features/admin/services/device_local_recovery_reset_service.dart';
import 'package:crm3_baf_ops/features/admin/services/device_recovery_command_service.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/services/notification_installation_registry.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

const _installation = '11111111-1111-4111-8111-111111111111';
const _requestId = '33333333-3333-4333-8333-333333333333';
const _globalCursor = 'baf_global_pull_cursor_v1:operator-1:generation-1';
const _workflowCursor = 'last_maintenance_workflow_pull_v2_workflows';
const _workflowQuarantine = 'last_maintenance_workflow_pull_v2_quarantine';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'last_global_pull': 'legacy-cursor',
      _globalCursor: 'scoped-cursor',
      _workflowCursor: 'workflow-cursor',
      _workflowQuarantine: 'workflow-quarantine',
      SharedPreferencesNotificationInstallationIdStore.preferenceKey:
          _installation,
      'isar.schema.provenance': 'preserved-marker',
      'unrelated.setting': true,
    });
  });

  test(
    'approved non-admin phone backs up and clears every local collection',
    () async {
      await _withDatabase((database) async {
        var backupCalls = 0;
        final service = _service(
          database,
          backupCreator: ({
            required diagnosticsText,
            required reason,
            manifestJsonText,
          }) async {
            backupCalls++;
            expect(await database.operationalDirectives.count(), 1);
            expect(await database.syncRejections.count(), 1);
            expect(diagnosticsText, contains('operator-1'));
            expect(manifestJsonText, contains('"cloudDataDeleted":false'));
            return _backup();
          },
        );

        final result = await service.reset(
          actor: _operator(),
          request: _request,
        );
        final preferences = await SharedPreferences.getInstance();

        expect(result.replayed, isFalse);
        expect(result.backupFileCount, 1);
        expect(result.backedUpUnsyncedRows, 1);
        expect(result.clearedCursorCount, 4);
        expect(backupCalls, 1);
        expect(await database.operationalDirectives.count(), 0);
        expect(await database.syncRejections.count(), 0);
        expect(preferences.containsKey('last_global_pull'), isFalse);
        expect(preferences.containsKey(_globalCursor), isFalse);
        expect(preferences.containsKey(_workflowCursor), isFalse);
        expect(preferences.containsKey(_workflowQuarantine), isFalse);
        expect(
          preferences.getString(
            SharedPreferencesNotificationInstallationIdStore.preferenceKey,
          ),
          _installation,
        );
        expect(
          preferences.getString('isar.schema.provenance'),
          'preserved-marker',
        );
        expect(preferences.getBool('unrelated.setting'), isTrue);
        expect(
          preferences.getBool('$deviceRecoveryCompletionPrefix$_requestId'),
          isTrue,
        );
      });
    },
  );

  test(
    'completed replay never clears freshly downloaded server records',
    () async {
      await _withDatabase((database) async {
        var backups = 0;
        final service = _service(
          database,
          backupCreator: ({
            required diagnosticsText,
            required reason,
            manifestJsonText,
          }) async {
            backups++;
            return _backup();
          },
        );
        await service.reset(actor: _operator(), request: _request);
        await database.writeTxn(() async {
          await database.operationalDirectives.put(_directive());
        });

        final result = await service.reset(
          actor: _operator(),
          request: _request,
        );

        expect(result.replayed, isTrue);
        expect(backups, 1);
        expect(await database.operationalDirectives.count(), 1);
      });
    },
  );

  test(
    'different account or phone is rejected before backup or deletion',
    () async {
      await _withDatabase((database) async {
        var backups = 0;
        final wrongAccount = _service(
          database,
          authenticatedUidLookup: () => 'another-user',
          backupCreator: ({
            required diagnosticsText,
            required reason,
            manifestJsonText,
          }) async {
            backups++;
            return _backup();
          },
        );

        await expectLater(
          wrongAccount.reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-account-mismatch')),
        );
        final wrongPhone = _service(
          database,
          installationIdReader:
              () async => '22222222-2222-4222-8222-222222222222',
        );
        await expectLater(
          wrongPhone.reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-installation-mismatch')),
        );
        expect(backups, 0);
        expect(await database.operationalDirectives.count(), 1);
        expect(
          (await SharedPreferences.getInstance()).containsKey(_globalCursor),
          isTrue,
        );
      });
    },
  );

  test(
    'backup exception leaves all cursors and local rows untouched',
    () async {
      await _withDatabase((database) async {
        final service = _service(
          database,
          backupCreator:
              ({
                required diagnosticsText,
                required reason,
                manifestJsonText,
              }) async => throw StateError('backup storage unavailable'),
        );

        await expectLater(
          service.reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-backup-failed')),
        );
        expect(await database.operationalDirectives.count(), 1);
        expect(await database.syncRejections.count(), 1);
        expect(
          (await SharedPreferences.getInstance()).containsKey(_globalCursor),
          isTrue,
        );
      });
    },
  );

  test(
    'copied lock file without primary database does not authorize deletion',
    () async {
      await _withDatabase((database) async {
        final service = _service(database, backup: _backup(primary: false));

        await expectLater(
          service.reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-backup-missing')),
        );
        expect(await database.operationalDirectives.count(), 1);
        expect(
          (await SharedPreferences.getInstance()).containsKey(_workflowCursor),
          isTrue,
        );
      });
    },
  );

  test(
    'failed primary copy is rejected even when other files were copied',
    () async {
      await _withDatabase((database) async {
        const result = IsarRecoveryPackageResult(
          directoryPath: '/protected-backup',
          reportPath: '/protected-backup/report.txt',
          copiedFileCount: 1,
          warnings: [],
          files: [
            IsarRecoveryFileEntry(
              sourcePath: '/data/default.isar',
              targetPath: '/protected-backup/default.isar',
              status: 'copy_failed',
            ),
            IsarRecoveryFileEntry(
              sourcePath: '/data/default.isar.lock',
              targetPath: '/protected-backup/default.isar.lock',
              status: 'copied',
            ),
          ],
        );

        await expectLater(
          _service(
            database,
            backup: result,
          ).reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-backup-missing')),
        );
        expect(await database.operationalDirectives.count(), 1);
      });
    },
  );

  test('cursor deletion failure never clears the database', () async {
    await _withDatabase((database) async {
      final service = _service(
        database,
        preferenceRemover: (preferences, key) async => false,
      );

      await expectLater(
        service.reset(actor: _operator(), request: _request),
        throwsA(_resetError('device-recovery-cursor-clear-failed')),
      );
      expect(await database.operationalDirectives.count(), 1);
      expect(await database.syncRejections.count(), 1);
    });
  });

  test(
    'account changing during backup refuses removal and preserves cursors',
    () async {
      await _withDatabase((database) async {
        var authenticatedUid = 'operator-1';
        final service = _service(
          database,
          authenticatedUidLookup: () => authenticatedUid,
          backupCreator: ({
            required diagnosticsText,
            required reason,
            manifestJsonText,
          }) async {
            authenticatedUid = 'another-user';
            return _backup();
          },
        );

        await expectLater(
          service.reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-account-mismatch')),
        );
        expect(await database.operationalDirectives.count(), 1);
        expect(
          (await SharedPreferences.getInstance()).containsKey(_globalCursor),
          isTrue,
        );
      });
    },
  );

  test(
    'damaged completion receipt refuses replay without further clearing',
    () async {
      await _withDatabase((database) async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(
          '$deviceRecoveryCompletionPrefix$_requestId',
          true,
        );

        await expectLater(
          _service(database).reset(actor: _operator(), request: _request),
          throwsA(_resetError('device-recovery-completion-marker-invalid')),
        );
        expect(await database.operationalDirectives.count(), 1);
      });
    },
  );
}

DeviceLocalRecoveryResetService _service(
  Isar database, {
  IsarRecoveryPackageResult? backup,
  DeviceRecoveryBackupCreator? backupCreator,
  DeviceRecoveryPreferenceRemover? preferenceRemover,
  String? Function()? authenticatedUidLookup,
  Future<String?> Function()? installationIdReader,
}) => DeviceLocalRecoveryResetService(
  databaseLookup: () => database,
  authenticatedUidLookup: authenticatedUidLookup ?? () => 'operator-1',
  installationIdReader: installationIdReader ?? () async => _installation,
  inventoryReader:
      (_) async => const DeviceRecoveryLocalInventory(
        totalRows: 2,
        unsyncedRows: 1,
        unresolvedRejections: 1,
      ),
  backupCreator:
      backupCreator ??
      ({required diagnosticsText, required reason, manifestJsonText}) async =>
          backup ?? _backup(),
  preferenceRemover: preferenceRemover,
);

IsarRecoveryPackageResult _backup({bool primary = true}) =>
    IsarRecoveryPackageResult(
      directoryPath: '/protected-backup',
      reportPath: '/protected-backup/report.txt',
      copiedFileCount: 1,
      warnings: const [],
      files: [
        IsarRecoveryFileEntry(
          sourcePath:
              primary ? '/data/default.isar' : '/data/default.isar.lock',
          targetPath:
              primary
                  ? '/protected-backup/default.isar'
                  : '/protected-backup/default.isar.lock',
          status: 'copied',
        ),
      ],
    );

const _request = DeviceRecoveryRequest(
  requestId: _requestId,
  targetUid: 'operator-1',
  installationId: _installation,
  requestedByUid: 'admin-1',
  requestedByName: 'Administrator',
  reason: 'Remove stale pilot records after a synchronization failure.',
  requestedAt: '2026-08-25T12:00:00.000Z',
  expiresAt: '2026-08-26T12:00:00.000Z',
);

AppUser _operator() => AppUser(
  uid: 'operator-1',
  name: 'Operator One',
  email: 'operator@example.invalid',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 25),
);

Matcher _resetError(String reasonCode) =>
    isA<DeviceRecoveryLocalResetException>().having(
      (error) => error.reasonCode,
      'reasonCode',
      reasonCode,
    );

Future<void> _withDatabase(Future<void> Function(Isar) operation) async {
  final directory = await Directory.systemTemp.createTemp('device_recovery_');
  final database = await Isar.open(
    [OperationalDirectiveSchema, SyncRejectionSchema],
    directory: directory.path,
    name: 'device_recovery_${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await database.writeTxn(() async {
      await database.operationalDirectives.put(_directive());
      await database.syncRejections.put(_rejection());
    });
    await operation(database);
  } finally {
    await database.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

OperationalDirective _directive() {
  final created = DateTime.utc(2026, 8, 25, 9);
  return OperationalDirective()
    ..firestoreId = 'directive-1'
    ..title = 'Operations instruction'
    ..description = 'Coordinate safe equipment movement.'
    ..directedTo = AppRole.operations
    ..status = DirectiveStatus.open
    ..priority = DirectivePriority.medium
    ..createdByUid = 'operator-1'
    ..createdByName = 'Operator One'
    ..issuedByUid = 'operator-1'
    ..issuedByName = 'Operator One'
    ..issuedAt = created
    ..isActive = true
    ..isDeleted = false
    ..createdAt = created
    ..updatedAt = created
    ..version = 1
    ..isSynced = false;
}

SyncRejection _rejection() =>
    SyncRejection()
      ..entityType = 'directive'
      ..entityId = 'directive-1'
      ..firestoreId = 'directive-1'
      ..message = 'Rejected by the authoritative server.'
      ..originatingUid = 'operator-1'
      ..isLikelyPermanent = true
      ..firstSeenAt = DateTime.utc(2026, 8, 25, 10)
      ..lastSeenAt = DateTime.utc(2026, 8, 25, 10)
      ..isResolved = false;
