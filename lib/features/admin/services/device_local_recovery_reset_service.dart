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

typedef DeviceRecoveryBackupEvidenceReader =
    Future<IsarRecoveryBackupEvidence?> Function(String path);

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

typedef DeviceRecoveryDurableJournalReader =
    Future<String?> Function(String requestId);

typedef DeviceRecoveryDurableJournalWriter =
    Future<void> Function(String requestId, String serialized);

class DeviceLocalRecoveryResetService {
  DeviceLocalRecoveryResetService({
    Isar? Function()? databaseLookup,
    String? Function()? authenticatedUidLookup,
    Future<String?> Function()? installationIdReader,
    Future<SharedPreferences> Function()? preferencesLoader,
    DeviceRecoveryInventoryReader? inventoryReader,
    DeviceRecoveryBackupCreator? backupCreator,
    DeviceRecoveryBackupVerifier? backupVerifier,
    DeviceRecoveryBackupEvidenceReader? backupEvidenceReader,
    DeviceRecoveryPreferenceRemover? preferenceRemover,
    DeviceRecoveryJournalWriter? journalWriter,
    DeviceRecoveryDurableJournalReader? durableJournalReader,
    DeviceRecoveryDurableJournalWriter? durableJournalWriter,
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
       _backupEvidenceReader =
           backupEvidenceReader ?? readIsarRecoveryBackupEvidence,
       _preferenceRemover =
           preferenceRemover ?? ((preferences, key) => preferences.remove(key)),
       _journalWriter =
           journalWriter ??
           ((preferences, key, value) => preferences.setString(key, value)),
       _durableJournalReader =
           durableJournalReader ?? readCrashDurableIsarRecoveryJournal,
       _durableJournalWriter =
           durableJournalWriter ?? writeCrashDurableIsarRecoveryJournal;

  final Isar? Function() _databaseLookup;
  final String? Function() _authenticatedUidLookup;
  final Future<String?> Function() _installationIdReader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final DeviceRecoveryInventoryReader _inventoryReader;
  final DeviceRecoveryBackupCreator _backupCreator;
  final DeviceRecoveryBackupVerifier _backupVerifier;
  final DeviceRecoveryBackupEvidenceReader _backupEvidenceReader;
  final DeviceRecoveryPreferenceRemover _preferenceRemover;
  final DeviceRecoveryJournalWriter _journalWriter;
  final DeviceRecoveryDurableJournalReader _durableJournalReader;
  final DeviceRecoveryDurableJournalWriter _durableJournalWriter;

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
    required bool claimedRecoveryOnly,
  }) async {
    if (claimedRecoveryOnly && request.status != 'in_progress') {
      throw const DeviceRecoveryLocalResetException(
        'A revoked account cannot clear data for an unclaimed recovery.',
        reasonCode: 'device-recovery-unclaimed-request',
      );
    }
    if (actor == null ||
        (!actor.isApproved && !claimedRecoveryOnly) ||
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

  Future<_CreatedRecoveryBackup> _createVerifiedBackup({
    required Isar database,
    required DeviceRecoveryRequest request,
    required DeviceRecoveryLocalInventory inventory,
    required bool resumed,
  }) async {
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
      'resumedRecoverySnapshot': resumed,
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
          ..writeln('resumedRecoverySnapshot: $resumed')
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
        reason:
            resumed
                ? 'admin_authorized_device_reset_resumed'
                : 'admin_authorized_device_reset',
        manifestJsonText: jsonEncode(manifest),
      );
    } catch (error) {
      throw DeviceRecoveryLocalResetException(
        'A protected database backup could not be created: $error',
        reasonCode: 'device-recovery-backup-failed',
        dataMayHaveBeenCleared: resumed,
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
      throw DeviceRecoveryLocalResetException(
        'No verified primary local-database backup was retained.',
        reasonCode: 'device-recovery-backup-missing',
        dataMayHaveBeenCleared: resumed,
      );
    }
    final primaryCopy = primaryCopies.single;
    final evidence = await _verifyRetainedBackup(
      primaryCopy.targetPath,
      dataMayHaveBeenCleared: resumed,
    );
    return _CreatedRecoveryBackup(
      package: backup,
      primaryPath: primaryCopy.targetPath,
      evidence: evidence,
      unsyncedRows: inventory.unsyncedRows,
    );
  }

  Future<DeviceRecoveryLocalResetResult> reset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
    bool claimedRecoveryOnly = false,
  }) async {
    if (kIsWeb) {
      throw const DeviceRecoveryLocalResetException(
        'Only installed mobile or desktop applications have a local database.',
        reasonCode: 'device-recovery-platform-unsupported',
      );
    }
    await _verifyActorAndInstallation(
      actor: actor,
      request: request,
      claimedRecoveryOnly: claimedRecoveryOnly,
    );
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
    final existingJournal = await _readPersistedJournal(
      preferences,
      journalKey,
      request: request,
    );
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
      if (existingJournal == null) {
        throw const DeviceRecoveryLocalResetException(
          'The prior local-reset completion has no protected backup journal.',
          reasonCode: 'device-recovery-completion-journal-missing',
          dataMayHaveBeenCleared: true,
        );
      }
      final journal = _DeviceRecoveryJournal.restore(
        existingJournal,
        request: request,
      );
      if (journal.backupDirectory != backupDirectory ||
          journal.backupFileCount != backupFiles ||
          journal.backedUpUnsyncedRows != unsyncedRows ||
          journal.cursorKeys.length != clearedCursors) {
        throw const DeviceRecoveryLocalResetException(
          'The prior local-reset completion does not match its backup journal.',
          reasonCode: 'device-recovery-completion-marker-invalid',
          dataMayHaveBeenCleared: true,
        );
      }
      await _verifyJournalBackups(journal, dataMayHaveBeenCleared: true);
      return DeviceRecoveryLocalResetResult(
        backupDirectory: backupDirectory,
        backupFileCount: backupFiles,
        clearedCursorCount: clearedCursors,
        backedUpUnsyncedRows: unsyncedRows,
        replayed: true,
      );
    }

    late _DeviceRecoveryJournal journal;
    try {
      await database.writeTxn(() async {
        if (existingJournal != null) {
          journal = _DeviceRecoveryJournal.restore(
            existingJournal,
            request: request,
          );
          await _verifyJournalBackups(journal, dataMayHaveBeenCleared: true);
          if (await database.getSize() > 0) {
            final inventory = await _inventoryReader(database);
            await _verifyActorAndInstallation(
              actor: actor,
              request: request,
              claimedRecoveryOnly: claimedRecoveryOnly,
            );
            final supplemental = await _createVerifiedBackup(
              database: database,
              request: request,
              inventory: inventory,
              resumed: true,
            );
            journal = journal.withSupplementalBackup(supplemental);
            await _persistJournal(
              preferences,
              journalKey,
              journal,
              dataMayHaveBeenCleared: true,
            );
          }
        } else {
          final inventory = await _inventoryReader(database);
          await _verifyActorAndInstallation(
            actor: actor,
            request: request,
            claimedRecoveryOnly: claimedRecoveryOnly,
          );
          final created = await _createVerifiedBackup(
            database: database,
            request: request,
            inventory: inventory,
            resumed: false,
          );
          await _verifyActorAndInstallation(
            actor: actor,
            request: request,
            claimedRecoveryOnly: claimedRecoveryOnly,
          );

          final cursorKeys =
              preferences.getKeys().where(_isSyncCursorKey).toList()..sort();
          journal = _DeviceRecoveryJournal(
            requestId: request.requestId,
            targetUid: request.targetUid,
            installationId: request.installationId,
            backupDirectory: created.package.directoryPath,
            backupPrimaryPath: created.primaryPath,
            backupByteCount: created.evidence.byteCount,
            backupSha256: created.evidence.sha256,
            backupFileCount: created.package.copiedFileCount,
            backedUpUnsyncedRows: inventory.unsyncedRows,
            supplementalBackups: const [],
            cursorKeys: cursorKeys,
          );
          await _persistJournal(
            preferences,
            journalKey,
            journal,
            dataMayHaveBeenCleared: false,
          );
        }

        await _verifyActorAndInstallation(
          actor: actor,
          request: request,
          claimedRecoveryOnly: claimedRecoveryOnly,
        );
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
        await _verifyActorAndInstallation(
          actor: actor,
          request: request,
          claimedRecoveryOnly: claimedRecoveryOnly,
        );
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

  Future<IsarRecoveryBackupEvidence> _verifyRetainedBackup(
    String path, {
    required bool dataMayHaveBeenCleared,
    int? expectedByteCount,
    String? expectedSha256,
  }) async {
    try {
      if (await _backupVerifier(path)) {
        final evidence = await _backupEvidenceReader(path);
        if (evidence != null &&
            (expectedByteCount == null ||
                evidence.byteCount == expectedByteCount) &&
            (expectedSha256 == null || evidence.sha256 == expectedSha256)) {
          return evidence;
        }
      }
    } catch (_) {
      // A missing or unreadable snapshot is never sufficient recovery proof.
    }
    throw DeviceRecoveryLocalResetException(
      'The retained local-database backup is missing, changed or unreadable.',
      reasonCode: 'device-recovery-backup-missing',
      dataMayHaveBeenCleared: dataMayHaveBeenCleared,
    );
  }

  Future<void> _verifyJournalBackups(
    _DeviceRecoveryJournal journal, {
    required bool dataMayHaveBeenCleared,
  }) async {
    await _verifyRetainedBackup(
      journal.backupPrimaryPath,
      expectedByteCount: journal.backupByteCount,
      expectedSha256: journal.backupSha256,
      dataMayHaveBeenCleared: dataMayHaveBeenCleared,
    );
    for (final backup in journal.supplementalBackups) {
      await _verifyRetainedBackup(
        backup.primaryPath,
        expectedByteCount: backup.byteCount,
        expectedSha256: backup.sha256,
        dataMayHaveBeenCleared: dataMayHaveBeenCleared,
      );
    }
  }

  Future<void> _persistJournal(
    SharedPreferences preferences,
    String key,
    _DeviceRecoveryJournal journal, {
    required bool dataMayHaveBeenCleared,
  }) async {
    final serialized = journal.toJson();
    await _writeAndVerifyDurableJournal(
      journal.requestId,
      serialized,
      dataMayHaveBeenCleared: dataMayHaveBeenCleared,
    );
    if (!await _journalWriter(preferences, key, serialized) ||
        preferences.getString(key) != serialized) {
      throw DeviceRecoveryLocalResetException(
        'The protected recovery journal could not be saved before deletion.',
        reasonCode: 'device-recovery-journal-write-failed',
        dataMayHaveBeenCleared: dataMayHaveBeenCleared,
      );
    }
  }

  Future<String?> _readPersistedJournal(
    SharedPreferences preferences,
    String key, {
    required DeviceRecoveryRequest request,
  }) async {
    String? durable;
    try {
      durable = await _durableJournalReader(request.requestId);
    } catch (error) {
      throw DeviceRecoveryLocalResetException(
        'The protected recovery journal could not be read: $error',
        reasonCode: 'device-recovery-journal-read-failed',
        dataMayHaveBeenCleared: true,
      );
    }
    if (durable != null) return durable;

    final legacy = preferences.get(key);
    if (legacy == null) return null;
    final restored = _DeviceRecoveryJournal.restore(legacy, request: request);
    final serialized = restored.toJson();
    await _writeAndVerifyDurableJournal(
      request.requestId,
      serialized,
      dataMayHaveBeenCleared: true,
    );
    return serialized;
  }

  Future<void> _writeAndVerifyDurableJournal(
    String requestId,
    String serialized, {
    required bool dataMayHaveBeenCleared,
  }) async {
    try {
      await _durableJournalWriter(requestId, serialized);
      if (await _durableJournalReader(requestId) != serialized) {
        throw const FormatException('Durable journal readback differs.');
      }
    } catch (error) {
      throw DeviceRecoveryLocalResetException(
        'The protected recovery journal could not be saved before deletion: '
        '$error',
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

class _CreatedRecoveryBackup {
  const _CreatedRecoveryBackup({
    required this.package,
    required this.primaryPath,
    required this.evidence,
    required this.unsyncedRows,
  });

  final IsarRecoveryPackageResult package;
  final String primaryPath;
  final IsarRecoveryBackupEvidence evidence;
  final int unsyncedRows;
}

class _SupplementalRecoveryBackup {
  const _SupplementalRecoveryBackup({
    required this.directory,
    required this.primaryPath,
    required this.byteCount,
    required this.sha256,
    required this.fileCount,
    required this.unsyncedRows,
  });

  final String directory;
  final String primaryPath;
  final int byteCount;
  final String sha256;
  final int fileCount;
  final int unsyncedRows;

  factory _SupplementalRecoveryBackup.restore(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid supplemental backup object.');
    }
    const fields = <String>{
      'directory',
      'primaryPath',
      'byteCount',
      'sha256',
      'fileCount',
      'unsyncedRows',
    };
    final directory = raw['directory'];
    final primaryPath = raw['primaryPath'];
    final byteCount = raw['byteCount'];
    final digest = raw['sha256'];
    final fileCount = raw['fileCount'];
    final unsyncedRows = raw['unsyncedRows'];
    if (raw.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(raw.keys.toSet()).isNotEmpty ||
        directory is! String ||
        directory.isEmpty ||
        primaryPath is! String ||
        !primaryPath.endsWith('.isar') ||
        byteCount is! int ||
        byteCount < 1 ||
        digest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        fileCount is! int ||
        fileCount < 1 ||
        unsyncedRows is! int ||
        unsyncedRows < 0) {
      throw const FormatException('Invalid supplemental backup evidence.');
    }
    return _SupplementalRecoveryBackup(
      directory: directory,
      primaryPath: primaryPath,
      byteCount: byteCount,
      sha256: digest,
      fileCount: fileCount,
      unsyncedRows: unsyncedRows,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'directory': directory,
    'primaryPath': primaryPath,
    'byteCount': byteCount,
    'sha256': sha256,
    'fileCount': fileCount,
    'unsyncedRows': unsyncedRows,
  };
}

class _DeviceRecoveryJournal {
  const _DeviceRecoveryJournal({
    required this.requestId,
    required this.targetUid,
    required this.installationId,
    required this.backupDirectory,
    required this.backupPrimaryPath,
    required this.backupByteCount,
    required this.backupSha256,
    required this.backupFileCount,
    required this.backedUpUnsyncedRows,
    required this.supplementalBackups,
    required this.cursorKeys,
  });

  final String requestId;
  final String targetUid;
  final String installationId;
  final String backupDirectory;
  final String backupPrimaryPath;
  final int backupByteCount;
  final String backupSha256;
  final int backupFileCount;
  final int backedUpUnsyncedRows;
  final List<_SupplementalRecoveryBackup> supplementalBackups;
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
      final backupByteCount = decoded['backupByteCount'];
      final backupSha256 = decoded['backupSha256'];
      final backupFileCount = decoded['backupFileCount'];
      final unsyncedRows = decoded['backedUpUnsyncedRows'];
      final supplementalRaw = decoded['supplementalBackups'];
      if (decoded['schemaVersion'] != 2 ||
          decoded['requestId'] != request.requestId ||
          decoded['targetUid'] != request.targetUid ||
          decoded['installationId'] != request.installationId ||
          backupDirectory is! String ||
          backupDirectory.isEmpty ||
          primaryPath is! String ||
          !primaryPath.endsWith('.isar') ||
          backupByteCount is! int ||
          backupByteCount < 1 ||
          backupSha256 is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(backupSha256) ||
          backupFileCount is! int ||
          backupFileCount < 1 ||
          unsyncedRows is! int ||
          unsyncedRows < 0 ||
          supplementalRaw is! List ||
          supplementalRaw.length > 32 ||
          keys is! List ||
          keys.any(
            (key) =>
                key is! String ||
                !DeviceLocalRecoveryResetService._isSyncCursorKey(key),
          )) {
        throw const FormatException('Invalid journal recovery evidence.');
      }
      final cursorKeys = keys.cast<String>().toList(growable: false);
      final supplemental = supplementalRaw
          .map(_SupplementalRecoveryBackup.restore)
          .toList(growable: false);
      if (cursorKeys.toSet().length != cursorKeys.length) {
        throw const FormatException('Duplicate journal synchronization key.');
      }
      final allBackupPaths = <String>[
        primaryPath,
        ...supplemental.map((backup) => backup.primaryPath),
      ];
      final supplementalFileCount = supplemental.fold<int>(
        0,
        (total, backup) => total + backup.fileCount,
      );
      final supplementalUnsyncedRows = supplemental.fold<int>(
        0,
        (total, backup) => total + backup.unsyncedRows,
      );
      if (allBackupPaths.toSet().length != allBackupPaths.length ||
          backupFileCount <= supplementalFileCount ||
          unsyncedRows < supplementalUnsyncedRows) {
        throw const FormatException('Inconsistent retained backup totals.');
      }
      return _DeviceRecoveryJournal(
        requestId: request.requestId,
        targetUid: request.targetUid,
        installationId: request.installationId,
        backupDirectory: backupDirectory,
        backupPrimaryPath: primaryPath,
        backupByteCount: backupByteCount,
        backupSha256: backupSha256,
        backupFileCount: backupFileCount,
        backedUpUnsyncedRows: unsyncedRows,
        supplementalBackups: supplemental,
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
        backupByteCount: backupByteCount,
        backupSha256: backupSha256,
        backupFileCount: backupFileCount,
        backedUpUnsyncedRows: backedUpUnsyncedRows,
        supplementalBackups: supplementalBackups,
        cursorKeys: keys,
      );

  _DeviceRecoveryJournal withSupplementalBackup(_CreatedRecoveryBackup backup) {
    if (supplementalBackups.length >= 32 ||
        backup.primaryPath == backupPrimaryPath ||
        supplementalBackups.any(
          (existing) => existing.primaryPath == backup.primaryPath,
        )) {
      throw const DeviceRecoveryLocalResetException(
        'The protected recovery journal cannot accept another backup.',
        reasonCode: 'device-recovery-supplemental-backup-invalid',
        dataMayHaveBeenCleared: true,
      );
    }
    return _DeviceRecoveryJournal(
      requestId: requestId,
      targetUid: targetUid,
      installationId: installationId,
      backupDirectory: backupDirectory,
      backupPrimaryPath: backupPrimaryPath,
      backupByteCount: backupByteCount,
      backupSha256: backupSha256,
      backupFileCount: backupFileCount + backup.package.copiedFileCount,
      backedUpUnsyncedRows: backedUpUnsyncedRows + backup.unsyncedRows,
      supplementalBackups: <_SupplementalRecoveryBackup>[
        ...supplementalBackups,
        _SupplementalRecoveryBackup(
          directory: backup.package.directoryPath,
          primaryPath: backup.primaryPath,
          byteCount: backup.evidence.byteCount,
          sha256: backup.evidence.sha256,
          fileCount: backup.package.copiedFileCount,
          unsyncedRows: backup.unsyncedRows,
        ),
      ],
      cursorKeys: cursorKeys,
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'schemaVersion': 2,
    'requestId': requestId,
    'targetUid': targetUid,
    'installationId': installationId,
    'backupDirectory': backupDirectory,
    'backupPrimaryPath': backupPrimaryPath,
    'backupByteCount': backupByteCount,
    'backupSha256': backupSha256,
    'backupFileCount': backupFileCount,
    'backedUpUnsyncedRows': backedUpUnsyncedRows,
    'supplementalBackups': supplementalBackups
        .map((backup) => backup.toJson())
        .toList(growable: false),
    'cursorKeys': cursorKeys,
  });
}

final deviceLocalRecoveryResetServiceProvider =
    Provider<DeviceLocalRecoveryResetService>(
      (ref) => DeviceLocalRecoveryResetService(),
    );
