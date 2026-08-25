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
const deviceRecoveryJournalPrefix = 'crm3.deviceRecovery.journal.v1.';

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
      required Isar database,
      required String diagnosticsText,
      required String reason,
      String? manifestJsonText,
    });

typedef DeviceRecoveryBackupVerifier = Future<bool> Function(String path);

typedef DeviceRecoveryInventoryReader =
    Future<DeviceRecoveryLocalInventory> Function(Isar database);

typedef DeviceRecoveryPreferenceRemover =
    Future<bool> Function(SharedPreferences preferences, String key);

typedef DeviceRecoveryJournalWriter =
    Future<bool> Function(
      SharedPreferences preferences,
      String key,
      String value,
    );

class DeviceLocalRecoveryResetService {
  DeviceLocalRecoveryResetService({
    Isar? Function()? databaseLookup,
    String? Function()? authenticatedUidLookup,
    Future<String?> Function()? installationIdReader,
    Future<SharedPreferences> Function()? preferencesLoader,
    DeviceRecoveryInventoryReader? inventoryReader,
    DeviceRecoveryBackupCreator? backupCreator,
    DeviceRecoveryBackupVerifier? backupVerifier,
    DeviceRecoveryPreferenceRemover? preferenceRemover,
    DeviceRecoveryJournalWriter? journalWriter,
  }) : _databaseLookup = databaseLookup ?? Isar.getInstance,
       _authenticatedUidLookup =
           authenticatedUidLookup ??
           (() => FirebaseAuth.instance.currentUser?.uid),
       _installationIdReader =
           installationIdReader ??
           SharedPreferencesNotificationInstallationIdStore().read,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _inventoryReader = inventoryReader ?? _readInventory,
       _backupCreator = backupCreator ?? createConsistentIsarRecoveryPackage,
       _backupVerifier = backupVerifier ?? isRetainedIsarRecoveryBackup,
       _preferenceRemover =
           preferenceRemover ?? ((preferences, key) => preferences.remove(key)),
       _journalWriter =
           journalWriter ??
           ((preferences, key, value) => preferences.setString(key, value));

  final Isar? Function() _databaseLookup;
  final String? Function() _authenticatedUidLookup;
  final Future<String?> Function() _installationIdReader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final DeviceRecoveryInventoryReader _inventoryReader;
  final DeviceRecoveryBackupCreator _backupCreator;
  final DeviceRecoveryBackupVerifier _backupVerifier;
  final DeviceRecoveryPreferenceRemover _preferenceRemover;
  final DeviceRecoveryJournalWriter _journalWriter;

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
    final journalKey = '$deviceRecoveryJournalPrefix${request.requestId}';
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

    final existingJournal = preferences.get(journalKey);
    _DeviceRecoveryJournal journal;
    if (existingJournal != null) {
      journal = _DeviceRecoveryJournal.restore(
        existingJournal,
        request: request,
      );
      await _verifyRetainedBackup(
        journal.backupPrimaryPath,
        dataMayHaveBeenCleared: true,
      );
    } else {
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
          database: database,
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
      final primaryCopies = backup.files.where(
        (file) =>
            file.status == 'copied' &&
            file.sourcePath.endsWith('.isar') &&
            !file.sourcePath.endsWith('.isar.lock') &&
            file.targetPath.endsWith('.isar'),
      );
      if (backup.copiedFileCount < 1 ||
          primaryCopyFailed ||
          primaryCopies.length != 1) {
        throw const DeviceRecoveryLocalResetException(
          'No verified primary local-database backup was retained.',
          reasonCode: 'device-recovery-backup-missing',
        );
      }
      final primaryCopy = primaryCopies.single;
      await _verifyRetainedBackup(
        primaryCopy.targetPath,
        dataMayHaveBeenCleared: false,
      );
      await _verifyActorAndInstallation(actor: actor, request: request);

      final cursorKeys =
          preferences.getKeys().where(_isSyncCursorKey).toList()..sort();
      journal = _DeviceRecoveryJournal(
        requestId: request.requestId,
        targetUid: request.targetUid,
        installationId: request.installationId,
        backupDirectory: backup.directoryPath,
        backupPrimaryPath: primaryCopy.targetPath,
        backupFileCount: backup.copiedFileCount,
        backedUpUnsyncedRows: inventory.unsyncedRows,
        cursorKeys: cursorKeys,
      );
      await _persistJournal(
        preferences,
        journalKey,
        journal,
        dataMayHaveBeenCleared: false,
      );
    }

    await _verifyActorAndInstallation(actor: actor, request: request);
    final currentCursorKeys =
        <String>{
            ...journal.cursorKeys,
            ...preferences.getKeys().where(_isSyncCursorKey),
          }.toList()
          ..sort();
    if (currentCursorKeys.length != journal.cursorKeys.length) {
      journal = journal.withCursorKeys(currentCursorKeys);
      await _persistJournal(
        preferences,
        journalKey,
        journal,
        dataMayHaveBeenCleared: existingJournal != null,
      );
    }
    for (final key in journal.cursorKeys) {
      if (!preferences.containsKey(key)) continue;
      if (!await _preferenceRemover(preferences, key) ||
          preferences.containsKey(key)) {
        throw DeviceRecoveryLocalResetException(
          'The durable synchronization cursor could not be cleared: $key',
          reasonCode: 'device-recovery-cursor-clear-failed',
          dataMayHaveBeenCleared: existingJournal != null,
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
          journal.backupFileCount,
        ) &&
        await preferences.setInt(
          '$marker.clearedCursors',
          journal.cursorKeys.length,
        ) &&
        await preferences.setInt(
          '$marker.unsyncedRows',
          journal.backedUpUnsyncedRows,
        ) &&
        await preferences.setString(
          '$marker.backupDirectory',
          journal.backupDirectory,
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
      backupDirectory: journal.backupDirectory,
      backupFileCount: journal.backupFileCount,
      clearedCursorCount: journal.cursorKeys.length,
      backedUpUnsyncedRows: journal.backedUpUnsyncedRows,
      replayed: false,
    );
  }

  Future<void> _verifyRetainedBackup(
    String path, {
    required bool dataMayHaveBeenCleared,
  }) async {
    try {
      if (await _backupVerifier(path)) return;
    } catch (_) {
      // A missing or unreadable snapshot is never sufficient recovery proof.
    }
    throw DeviceRecoveryLocalResetException(
      'The retained local-database backup is missing or unreadable.',
      reasonCode: 'device-recovery-backup-missing',
      dataMayHaveBeenCleared: dataMayHaveBeenCleared,
    );
  }

  Future<void> _persistJournal(
    SharedPreferences preferences,
    String key,
    _DeviceRecoveryJournal journal, {
    required bool dataMayHaveBeenCleared,
  }) async {
    final serialized = journal.toJson();
    if (!await _journalWriter(preferences, key, serialized) ||
        preferences.getString(key) != serialized) {
      throw DeviceRecoveryLocalResetException(
        'The protected recovery journal could not be saved before deletion.',
        reasonCode: 'device-recovery-journal-write-failed',
        dataMayHaveBeenCleared: dataMayHaveBeenCleared,
      );
    }
  }

  static bool _isSyncCursorKey(String key) =>
      key == SharedPreferencesGlobalPullCursorStore.legacyGlobalCursorKey ||
      key == SharedPreferencesGlobalPullCursorStore.keyPrefix ||
      key.startsWith('${SharedPreferencesGlobalPullCursorStore.keyPrefix}:') ||
      key == 'last_maintenance_workflow_pull_v2' ||
      key.startsWith('last_maintenance_workflow_pull_v2_');
}

class _DeviceRecoveryJournal {
  const _DeviceRecoveryJournal({
    required this.requestId,
    required this.targetUid,
    required this.installationId,
    required this.backupDirectory,
    required this.backupPrimaryPath,
    required this.backupFileCount,
    required this.backedUpUnsyncedRows,
    required this.cursorKeys,
  });

  final String requestId;
  final String targetUid;
  final String installationId;
  final String backupDirectory;
  final String backupPrimaryPath;
  final int backupFileCount;
  final int backedUpUnsyncedRows;
  final List<String> cursorKeys;

  factory _DeviceRecoveryJournal.restore(
    Object raw, {
    required DeviceRecoveryRequest request,
  }) {
    try {
      if (raw is! String) throw const FormatException('Invalid journal value.');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid journal object.');
      }
      final keys = decoded['cursorKeys'];
      final backupDirectory = decoded['backupDirectory'];
      final primaryPath = decoded['backupPrimaryPath'];
      final backupFileCount = decoded['backupFileCount'];
      final unsyncedRows = decoded['backedUpUnsyncedRows'];
      if (decoded['schemaVersion'] != 1 ||
          decoded['requestId'] != request.requestId ||
          decoded['targetUid'] != request.targetUid ||
          decoded['installationId'] != request.installationId ||
          backupDirectory is! String ||
          backupDirectory.isEmpty ||
          primaryPath is! String ||
          !primaryPath.endsWith('.isar') ||
          backupFileCount is! int ||
          backupFileCount < 1 ||
          unsyncedRows is! int ||
          unsyncedRows < 0 ||
          keys is! List ||
          keys.any(
            (key) =>
                key is! String ||
                !DeviceLocalRecoveryResetService._isSyncCursorKey(key),
          )) {
        throw const FormatException('Invalid journal recovery evidence.');
      }
      final cursorKeys = keys.cast<String>().toList(growable: false);
      if (cursorKeys.toSet().length != cursorKeys.length) {
        throw const FormatException('Duplicate journal synchronization key.');
      }
      return _DeviceRecoveryJournal(
        requestId: request.requestId,
        targetUid: request.targetUid,
        installationId: request.installationId,
        backupDirectory: backupDirectory,
        backupPrimaryPath: primaryPath,
        backupFileCount: backupFileCount,
        backedUpUnsyncedRows: unsyncedRows,
        cursorKeys: cursorKeys,
      );
    } catch (_) {
      throw const DeviceRecoveryLocalResetException(
        'The existing local-recovery journal is incomplete or inconsistent.',
        reasonCode: 'device-recovery-journal-invalid',
        dataMayHaveBeenCleared: true,
      );
    }
  }

  _DeviceRecoveryJournal withCursorKeys(List<String> keys) =>
      _DeviceRecoveryJournal(
        requestId: requestId,
        targetUid: targetUid,
        installationId: installationId,
        backupDirectory: backupDirectory,
        backupPrimaryPath: backupPrimaryPath,
        backupFileCount: backupFileCount,
        backedUpUnsyncedRows: backedUpUnsyncedRows,
        cursorKeys: keys,
      );

  String toJson() => jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'requestId': requestId,
    'targetUid': targetUid,
    'installationId': installationId,
    'backupDirectory': backupDirectory,
    'backupPrimaryPath': backupPrimaryPath,
    'backupFileCount': backupFileCount,
    'backedUpUnsyncedRows': backedUpUnsyncedRows,
    'cursorKeys': cursorKeys,
  });
}

final deviceLocalRecoveryResetServiceProvider =
    Provider<DeviceLocalRecoveryResetService>(
      (ref) => DeviceLocalRecoveryResetService(),
    );
