import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/global_pull_cursor_store.dart';
import '../../../core/services/isar_production_recovery.dart';
import '../../auth/data/user_model.dart';
import '../../auth/services/notification_installation_registry.dart';
import 'device_recovery_command_service.dart';
import 'local_diagnostics_read_adapter.dart';

const deviceRecoveryCompletionPrefix = 'crm3.deviceRecovery.completed.v1.';

class DeviceRecoveryLocalInventory {
  const DeviceRecoveryLocalInventory({
    required this.totalRows,
    required this.unsyncedRows,
    required this.unresolvedRejections,
  });

  final int totalRows;
  final int unsyncedRows;
  final int unresolvedRejections;
}

class DeviceRecoveryLocalResetResult {
  const DeviceRecoveryLocalResetResult({
    required this.backupDirectory,
    required this.backupFileCount,
    required this.clearedCursorCount,
    required this.backedUpUnsyncedRows,
    required this.replayed,
  });

  final String backupDirectory;
  final int backupFileCount;
  final int clearedCursorCount;
  final int backedUpUnsyncedRows;
  final bool replayed;
}

class DeviceRecoveryLocalResetException implements Exception {
  const DeviceRecoveryLocalResetException(
    this.message, {
    required this.reasonCode,
    this.dataMayHaveBeenCleared = false,
  });

  final String message;
  final String reasonCode;
  final bool dataMayHaveBeenCleared;

  @override
  String toString() => message;
}

typedef DeviceRecoveryBackupCreator =
    Future<IsarRecoveryPackageResult> Function({
      required String diagnosticsText,
      required String reason,
      String? manifestJsonText,
    });

typedef DeviceRecoveryInventoryReader =
    Future<DeviceRecoveryLocalInventory> Function(Isar database);

typedef DeviceRecoveryPreferenceRemover =
    Future<bool> Function(SharedPreferences preferences, String key);

class DeviceLocalRecoveryResetService {
  DeviceLocalRecoveryResetService({
    Isar? Function()? databaseLookup,
    String? Function()? authenticatedUidLookup,
    Future<String?> Function()? installationIdReader,
    Future<SharedPreferences> Function()? preferencesLoader,
    DeviceRecoveryInventoryReader? inventoryReader,
    DeviceRecoveryBackupCreator? backupCreator,
    DeviceRecoveryPreferenceRemover? preferenceRemover,
  }) : _databaseLookup = databaseLookup ?? Isar.getInstance,
       _authenticatedUidLookup =
           authenticatedUidLookup ??
           (() => FirebaseAuth.instance.currentUser?.uid),
       _installationIdReader =
           installationIdReader ??
           SharedPreferencesNotificationInstallationIdStore().read,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _inventoryReader = inventoryReader ?? _readInventory,
       _backupCreator = backupCreator ?? createIsarRecoveryPackage,
       _preferenceRemover =
           preferenceRemover ?? ((preferences, key) => preferences.remove(key));

  final Isar? Function() _databaseLookup;
  final String? Function() _authenticatedUidLookup;
  final Future<String?> Function() _installationIdReader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final DeviceRecoveryInventoryReader _inventoryReader;
  final DeviceRecoveryBackupCreator _backupCreator;
  final DeviceRecoveryPreferenceRemover _preferenceRemover;

  static Future<DeviceRecoveryLocalInventory> _readInventory(
    Isar database,
  ) async {
    final snapshot =
        await LocalDiagnosticsReadAdapter(
          databaseLookup: () => database,
        ).read();
    return DeviceRecoveryLocalInventory(
      totalRows: snapshot.rows.fold<int>(
        0,
        (total, row) => total + row.totalCount,
      ),
      unsyncedRows: snapshot.rows.fold<int>(
        0,
        (total, row) => total + row.unsyncedCount,
      ),
      unresolvedRejections: snapshot.unresolvedRejections,
    );
  }

  Future<void> _verifyActorAndInstallation({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
  }) async {
    if (actor == null ||
        !actor.isApproved ||
        actor.uid != request.targetUid ||
        _authenticatedUidLookup() != request.targetUid) {
      throw const DeviceRecoveryLocalResetException(
        'The signed-in account does not match the requested target phone.',
        reasonCode: 'device-recovery-account-mismatch',
      );
    }
    if (await _installationIdReader() != request.installationId) {
      throw const DeviceRecoveryLocalResetException(
        'This phone does not match the administrator-selected installation.',
        reasonCode: 'device-recovery-installation-mismatch',
      );
    }
  }

  Future<DeviceRecoveryLocalResetResult> reset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
  }) async {
    if (kIsWeb) {
      throw const DeviceRecoveryLocalResetException(
        'Only installed mobile or desktop applications have a local database.',
        reasonCode: 'device-recovery-platform-unsupported',
      );
    }
    await _verifyActorAndInstallation(actor: actor, request: request);
    final database = _databaseLookup();
    if (database == null) {
      throw const DeviceRecoveryLocalResetException(
        'The local application database is unavailable.',
        reasonCode: 'device-recovery-database-unavailable',
      );
    }
    final preferences = await _preferencesLoader();
    final marker = '$deviceRecoveryCompletionPrefix${request.requestId}';
    if (preferences.getBool(marker) == true) {
      final backupFiles = preferences.getInt('$marker.backupFiles');
      final clearedCursors = preferences.getInt('$marker.clearedCursors');
      final unsyncedRows = preferences.getInt('$marker.unsyncedRows');
      final backupDirectory = preferences.getString('$marker.backupDirectory');
      if (backupFiles == null ||
          backupFiles < 1 ||
          clearedCursors == null ||
          clearedCursors < 0 ||
          unsyncedRows == null ||
          unsyncedRows < 0 ||
          backupDirectory == null ||
          backupDirectory.isEmpty) {
        throw const DeviceRecoveryLocalResetException(
          'The prior local-reset completion evidence is incomplete.',
          reasonCode: 'device-recovery-completion-marker-invalid',
          dataMayHaveBeenCleared: true,
        );
      }
      return DeviceRecoveryLocalResetResult(
        backupDirectory: backupDirectory,
        backupFileCount: backupFiles,
        clearedCursorCount: clearedCursors,
        backedUpUnsyncedRows: unsyncedRows,
        replayed: true,
      );
    }

    final inventory = await _inventoryReader(database);
    await _verifyActorAndInstallation(actor: actor, request: request);
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'mode': 'admin_authorized_remote_device_reset',
      'requestId': request.requestId,
      'targetUid': request.targetUid,
      'installationId': request.installationId,
      'requestedByUid': request.requestedByUid,
      'requestedByName': request.requestedByName,
      'reason': request.reason,
      'requestedAt': request.requestedAt,
      'createdAt': createdAt,
      'totalLocalRows': inventory.totalRows,
      'backedUpUnsyncedRows': inventory.unsyncedRows,
      'unresolvedSyncRejections': inventory.unresolvedRejections,
      'cloudDataDeleted': false,
      'authenticationCleared': false,
    };
    final diagnostics =
        StringBuffer()
          ..writeln('Administrator-authorized device-local recovery')
          ..writeln('requestId: ${request.requestId}')
          ..writeln('targetUid: ${request.targetUid}')
          ..writeln('installationId: ${request.installationId}')
          ..writeln('requestedByUid: ${request.requestedByUid}')
          ..writeln('totalLocalRows: ${inventory.totalRows}')
          ..writeln('backedUpUnsyncedRows: ${inventory.unsyncedRows}')
          ..writeln(
            'unresolvedSyncRejections: ${inventory.unresolvedRejections}',
          )
          ..writeln('reason: ${request.reason}');

    late final IsarRecoveryPackageResult backup;
    try {
      backup = await _backupCreator(
        diagnosticsText: diagnostics.toString(),
        reason: 'admin_authorized_device_reset',
        manifestJsonText: jsonEncode(manifest),
      );
    } catch (error) {
      throw DeviceRecoveryLocalResetException(
        'A protected database backup could not be created: $error',
        reasonCode: 'device-recovery-backup-failed',
      );
    }
    final primaryCopyFailed = backup.files.any(
      (file) =>
          file.status == 'copy_failed' &&
          file.sourcePath.endsWith('.isar') &&
          !file.sourcePath.endsWith('.isar.lock'),
    );
    final primaryCopyRetained = backup.files.any(
      (file) =>
          file.status == 'copied' &&
          file.sourcePath.endsWith('.isar') &&
          !file.sourcePath.endsWith('.isar.lock'),
    );
    if (backup.copiedFileCount < 1 ||
        primaryCopyFailed ||
        !primaryCopyRetained) {
      throw const DeviceRecoveryLocalResetException(
        'No verified primary local-database backup was retained.',
        reasonCode: 'device-recovery-backup-missing',
      );
    }
    await _verifyActorAndInstallation(actor: actor, request: request);

    final cursorKeys =
        preferences.getKeys().where(_isSyncCursorKey).toList()..sort();
    for (final key in cursorKeys) {
      if (!await _preferenceRemover(preferences, key) ||
          preferences.containsKey(key)) {
        throw DeviceRecoveryLocalResetException(
          'The durable synchronization cursor could not be cleared: $key',
          reasonCode: 'device-recovery-cursor-clear-failed',
        );
      }
    }
    await _verifyActorAndInstallation(actor: actor, request: request);

    try {
      await database.writeTxn(() async {
        if (_authenticatedUidLookup() != request.targetUid) {
          throw const DeviceRecoveryLocalResetException(
            'The signed-in account changed before local data removal.',
            reasonCode: 'device-recovery-account-changed',
          );
        }
        await database.clear();
      });
    } catch (error) {
      if (error is DeviceRecoveryLocalResetException) rethrow;
      throw DeviceRecoveryLocalResetException(
        'The local database could not be cleared safely: $error',
        reasonCode: 'device-recovery-database-clear-failed',
        dataMayHaveBeenCleared: true,
      );
    }

    final persisted =
        await preferences.setInt(
          '$marker.backupFiles',
          backup.copiedFileCount,
        ) &&
        await preferences.setInt('$marker.clearedCursors', cursorKeys.length) &&
        await preferences.setInt(
          '$marker.unsyncedRows',
          inventory.unsyncedRows,
        ) &&
        await preferences.setString(
          '$marker.backupDirectory',
          backup.directoryPath,
        ) &&
        await preferences.setBool(marker, true);
    if (!persisted || preferences.getBool(marker) != true) {
      throw const DeviceRecoveryLocalResetException(
        'The local reset completed, but its replay-safe receipt was not saved.',
        reasonCode: 'device-recovery-completion-marker-write-failed',
        dataMayHaveBeenCleared: true,
      );
    }

    return DeviceRecoveryLocalResetResult(
      backupDirectory: backup.directoryPath,
      backupFileCount: backup.copiedFileCount,
      clearedCursorCount: cursorKeys.length,
      backedUpUnsyncedRows: inventory.unsyncedRows,
      replayed: false,
    );
  }

  static bool _isSyncCursorKey(String key) =>
      key == SharedPreferencesGlobalPullCursorStore.legacyGlobalCursorKey ||
      key == SharedPreferencesGlobalPullCursorStore.keyPrefix ||
      key.startsWith('${SharedPreferencesGlobalPullCursorStore.keyPrefix}:') ||
      key == 'last_maintenance_workflow_pull_v2' ||
      key.startsWith('last_maintenance_workflow_pull_v2_');
}

final deviceLocalRecoveryResetServiceProvider =
    Provider<DeviceLocalRecoveryResetService>(
      (ref) => DeviceLocalRecoveryResetService(),
    );
