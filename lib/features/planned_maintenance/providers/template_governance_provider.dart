// FILE: lib/features/planned_maintenance/providers/template_governance_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../../main.dart';
import '../../auth/data/user_model.dart';
import '../data/template_governance_model.dart';
import '../domain/template_version_snapshot_contract.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';

// ─────────────────────────────────────────────────────────────
// NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _cleanRequiredText(String? value, String fallback) {
  final cleaned = _cleanOptionalText(value);
  return cleaned ?? fallback;
}

List<String> _cleanStringList(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

void _validateTemplateVersionSnapshotForPublish(TemplateVersion record) {
  late final TemplateVersionSnapshotValidationResult validation;
  try {
    validation = TemplateVersionSnapshotBundle.fromRawJson(
      jobTemplateSnapshotJson: record.jobTemplateSnapshotJson,
      moduleSnapshotsJson: record.moduleSnapshotsJson,
      fieldDefinitionsJson: record.fieldDefinitionsJson,
      checklistJson: record.checklistJson,
    ).validate(requireClosureReviewForClosureCritical: true);
  } on TemplateVersionSnapshotException catch (e) {
    throw StateError(
      'Template version cannot be published because its governance snapshot is invalid: '
      '${e.message}',
    );
  }

  if (validation.errors.isEmpty) return;

  throw StateError(
    'Template version cannot be published because its governance snapshot is invalid: '
    '${validation.errors.first}',
  );
}

DateTime? _readPackageCreatedAtSafely(TemplatePackage record) {
  try {
    return record.createdAt;
  } catch (_) {
    return null;
  }
}

DateTime? _readPackageUpdatedAtSafely(TemplatePackage record) {
  try {
    return record.updatedAt;
  } catch (_) {
    return null;
  }
}

DateTime? _readVersionCreatedAtSafely(TemplateVersion record) {
  try {
    return record.createdAt;
  } catch (_) {
    return null;
  }
}

DateTime? _readVersionUpdatedAtSafely(TemplateVersion record) {
  try {
    return record.updatedAt;
  } catch (_) {
    return null;
  }
}

DateTime? _readAuditPerformedAtSafely(TemplatePublishAudit record) {
  try {
    return record.performedAt;
  } catch (_) {
    return null;
  }
}

String _newPackageFirestoreId() =>
    FirebaseFirestore.instance.collection('template_packages').doc().id;

String _newVersionFirestoreId() =>
    FirebaseFirestore.instance.collection('template_versions').doc().id;

String _newAuditFirestoreId() =>
    FirebaseFirestore.instance.collection('template_publish_audits').doc().id;

void _requireTemplateGovernor(AppUser actor, String actionLabel) {
  if (!actor.canManageTemplateGovernance) {
    throw StateError('Not authorized to $actionLabel.');
  }
}

void _normalizePackageForUserSave(
  TemplatePackage record, {
  required AppUser actor,
  required bool markUnsynced,
  bool preserveCreatedAt = true,
  bool incrementVersion = true,
}) {
  final now = DateTime.now();

  record.firestoreId ??= _newPackageFirestoreId();

  final existingCreatedAt = _readPackageCreatedAtSafely(record);
  final existingUpdatedAt = _readPackageUpdatedAtSafely(record);

  record
    ..packageCode = record.packageCode.trim()
    ..title = record.title.trim()
    ..description = _cleanOptionalText(record.description)
    ..assetType = _cleanOptionalText(record.assetType)
    ..assetNumberScope = _cleanOptionalText(record.assetNumberScope)
    ..disciplineScope = _cleanOptionalText(record.disciplineScope)
    ..activeVersionFirestoreId = _cleanOptionalText(
      record.activeVersionFirestoreId,
    )
    ..createdAt =
        preserveCreatedAt && existingCreatedAt != null ? existingCreatedAt : now
    ..updatedAt = now
    ..createdByUid ??= actor.uid
    ..createdByName ??= actor.name
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..retiredByUid = _cleanOptionalText(record.retiredByUid)
    ..retiredByName = _cleanOptionalText(record.retiredByName)
    ..retireReason = _cleanOptionalText(record.retireReason)
    ..deletedByUid = _cleanOptionalText(record.deletedByUid)
    ..deletedByName = _cleanOptionalText(record.deletedByName)
    ..deleteReason = _cleanOptionalText(record.deleteReason)
    ..targetRefs = _cleanStringList(record.targetRefs)
    ..deviceTagRefs = _cleanStringList(record.deviceTagRefs)
    ..safetyClass = _cleanOptionalText(record.safetyClass)
    ..safetyGatePolicyJson = _cleanOptionalText(record.safetyGatePolicyJson)
    ..procedureRefs = _cleanStringList(record.procedureRefs)
    ..operationalStatePreconditions = _cleanStringList(
      record.operationalStatePreconditions,
    )
    ..metadataJson = _cleanOptionalText(record.metadataJson);

  if (existingUpdatedAt == null) {
    record.updatedAt = now;
  }

  if (incrementVersion) {
    record.version += 1;
  }

  if (markUnsynced) {
    record.isSynced = false;
  }
}

void _normalizeVersionForUserSave(
  TemplateVersion record, {
  required AppUser actor,
  required bool markUnsynced,
  bool preserveCreatedAt = true,
  bool incrementVersion = true,
}) {
  final now = DateTime.now();

  record.firestoreId ??= _newVersionFirestoreId();

  final existingCreatedAt = _readVersionCreatedAtSafely(record);
  final existingUpdatedAt = _readVersionUpdatedAtSafely(record);

  record
    ..packageFirestoreId = _cleanOptionalText(record.packageFirestoreId)
    ..versionLabel = _cleanOptionalText(record.versionLabel)
    ..sourceVersionFirestoreId = _cleanOptionalText(
      record.sourceVersionFirestoreId,
    )
    ..contentHash = _cleanOptionalText(record.contentHash)
    ..jobTemplateSnapshotJson = _cleanRequiredText(
      record.jobTemplateSnapshotJson,
      '{}',
    )
    ..moduleSnapshotsJson = _cleanRequiredText(record.moduleSnapshotsJson, '[]')
    ..fieldDefinitionsJson = _cleanRequiredText(
      record.fieldDefinitionsJson,
      '[]',
    )
    ..checklistJson = _cleanRequiredText(record.checklistJson, '[]')
    ..releaseNotes = _cleanOptionalText(record.releaseNotes)
    ..changeSummary = _cleanOptionalText(record.changeSummary)
    ..createdAt =
        preserveCreatedAt && existingCreatedAt != null ? existingCreatedAt : now
    ..updatedAt = now
    ..createdByUid ??= actor.uid
    ..createdByName ??= actor.name
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..publishedByUid = _cleanOptionalText(record.publishedByUid)
    ..publishedByName = _cleanOptionalText(record.publishedByName)
    ..retiredByUid = _cleanOptionalText(record.retiredByUid)
    ..retiredByName = _cleanOptionalText(record.retiredByName)
    ..retireReason = _cleanOptionalText(record.retireReason)
    ..minAppVersion = _cleanOptionalText(record.minAppVersion)
    ..deletedByUid = _cleanOptionalText(record.deletedByUid)
    ..deletedByName = _cleanOptionalText(record.deletedByName)
    ..deleteReason = _cleanOptionalText(record.deleteReason)
    ..targetRefs = _cleanStringList(record.targetRefs)
    ..deviceTagRefs = _cleanStringList(record.deviceTagRefs)
    ..safetyClass = _cleanOptionalText(record.safetyClass)
    ..safetyGatePolicyJson = _cleanOptionalText(record.safetyGatePolicyJson)
    ..procedureRefs = _cleanStringList(record.procedureRefs)
    ..operationalStatePreconditions = _cleanStringList(
      record.operationalStatePreconditions,
    )
    ..metadataJson = _cleanOptionalText(record.metadataJson);

  record.refreshClosureReviewStateFromSnapshots();

  if (existingUpdatedAt == null) {
    record.updatedAt = now;
  }

  if (record.status != TemplateVersionStatus.draft &&
      _cleanOptionalText(record.contentHash) == null) {
    record.refreshContentHash();
  }

  if (incrementVersion) {
    record.version += 1;
  }

  if (markUnsynced) {
    record.isSynced = false;
  }
}

TemplatePublishAudit _newAudit({
  required TemplatePublishAuditAction action,
  required AppUser actor,
  required TemplateVersion version,
  String? reason,
  String? beforeHash,
  String? afterHash,
}) {
  final now = DateTime.now();
  return TemplatePublishAudit()
    ..firestoreId = _newAuditFirestoreId()
    ..packageFirestoreId = version.packageFirestoreId
    ..versionFirestoreId = version.firestoreId
    ..action = action
    ..performedByUid = actor.uid
    ..performedByName = actor.name
    ..performedAt = now
    ..updatedAt = now
    ..reason = _cleanOptionalText(reason)
    ..beforeHash = _cleanOptionalText(beforeHash)
    ..afterHash = _cleanOptionalText(afterHash)
    ..payloadSnapshotJson = jsonEncode(version.toMap())
    ..isSynced = false;
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedTemplatePackageResult {
  final List<TemplatePackage> records;
  final DocumentSnapshot? lastDoc;

  PaginatedTemplatePackageResult({required this.records, this.lastDoc});
}

class PaginatedTemplateVersionResult {
  final List<TemplateVersion> records;
  final DocumentSnapshot? lastDoc;

  PaginatedTemplateVersionResult({required this.records, this.lastDoc});
}

class PaginatedTemplateAuditResult {
  final List<TemplatePublishAudit> records;
  final DocumentSnapshot? lastDoc;

  PaginatedTemplateAuditResult({required this.records, this.lastDoc});
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class TemplateGovernanceRepository {
  Future<void> savePackage(TemplatePackage record, {required AppUser actor});
  Future<void> saveVersion(TemplateVersion record, {required AppUser actor});

  Future<void> publishVersion(
    TemplateVersion record, {
    required AppUser actor,
    String? reason,
  });

  Future<void> retireVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  });

  Future<void> saveAudit(TemplatePublishAudit record);

  Future<List<TemplatePackage>> getAllPackages();
  Stream<List<TemplatePackage>> watchPackages({int? limit});
  Future<TemplatePackage?> getPackageById(dynamic id);
  Future<TemplatePackage?> getPackageByFirestoreId(String firestoreId);

  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  );
  Stream<List<TemplateVersion>> watchVersionsForPackage(
    String packageFirestoreId,
  );
  Future<TemplateVersion?> getVersionById(dynamic id);
  Future<TemplateVersion?> getVersionByFirestoreId(String firestoreId);

  Future<List<TemplatePublishAudit>> getAuditsForVersion(
    String versionFirestoreId,
  );
  Future<TemplatePublishAudit?> getAuditByFirestoreId(String firestoreId);

  Future<List<TemplatePackage>> getUnsyncedPackages();
  Future<void> markPackagesSynced(List<int> ids);
  Future<void> markPackagesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> insertPackageFromRemote(TemplatePackage remote);
  Future<void> updatePackageFromRemote(TemplatePackage remote);
  Future<RemoteTombstoneApplyResult> applyTombstoneFromPackageRemote(
    TemplatePackage remote,
  );

  Future<List<TemplateVersion>> getUnsyncedVersions();
  Future<void> markVersionsSynced(List<int> ids);
  Future<void> markVersionsSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> insertVersionFromRemote(TemplateVersion remote);
  Future<void> updateVersionFromRemote(TemplateVersion remote);
  Future<RemoteTombstoneApplyResult> applyTombstoneFromVersionRemote(
    TemplateVersion remote,
  );

  Future<List<TemplatePublishAudit>> getUnsyncedAudits();
  Future<void> markAuditsSynced(List<int> ids);
  Future<void> markAuditsSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> insertAuditFromRemote(TemplatePublishAudit remote);

  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<List<TemplatePackage>> getPackagesByFirestoreIds(List<String> ids);
  Future<void> batchUpsertPackages(List<TemplatePackage> records);

  Future<List<TemplateVersion>> getVersionsByFirestoreIds(List<String> ids);
  Future<void> batchUpsertVersions(List<TemplateVersion> records);

  /// Creates the missing remote draft predecessor for a locally-published
  /// TemplateVersion whose draft never reached Firestore.
  ///
  /// This is a remote-only lifecycle replay primitive used by SyncService. It
  /// must receive a draft-shaped full document that satisfies the Firestore
  /// create rule. Local repositories deliberately do not support this method.
  Future<void> createRemoteTemplateVersionDraftReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData,
  );

  /// Applies the second replay step, updating a remote draft TemplateVersion
  /// to the locally-published state using a field-scoped merge payload.
  ///
  /// This keeps Firestore rules strict: clients never create published
  /// TemplateVersions directly, but sync can replay the missing draft→publish
  /// lifecycle when local offline work collapsed those states.
  Future<void> applyRemoteTemplateVersionPublishReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> publishData,
  );

  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(List<String> ids);
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records);
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class IsarTemplateGovernanceRepository implements TemplateGovernanceRepository {
  @override
  Future<void> savePackage(
    TemplatePackage record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template packages');
    _normalizePackageForUserSave(record, actor: actor, markUnsynced: true);
    await isar.writeTxn(() => isar.templatePackages.put(record));
  }

  @override
  Future<void> saveVersion(
    TemplateVersion record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions are editable.');
    }
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);
    await isar.writeTxn(() => isar.templateVersions.put(record));
  }

  @override
  Future<void> publishVersion(
    TemplateVersion record, {
    required AppUser actor,
    String? reason,
  }) async {
    _requireTemplateGovernor(actor, 'publish template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions can be published.');
    }
    if (record.firestoreId != null && !record.isSynced) {
      throw StateError(
        'A saved TemplateVersion draft must sync successfully before it can be published.',
      );
    }

    _validateTemplateVersionSnapshotForPublish(record);

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.published
      ..publishedByUid = actor.uid
      ..publishedByName = actor.name
      ..publishedAt = now
      ..updatedAt = now;
    record.refreshContentHash();
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.published,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    );

    await isar.writeTxn(() async {
      await isar.templateVersions.put(record);
      await isar.templatePublishAudits.put(audit);

      final packageId = record.packageFirestoreId;
      if (packageId != null) {
        final package =
            await isar.templatePackages
                .filter()
                .firestoreIdEqualTo(packageId)
                .findFirst();
        if (package != null) {
          package
            ..activeVersionFirestoreId = record.firestoreId
            ..latestVersionNumber =
                record.versionNumber > package.latestVersionNumber
                    ? record.versionNumber
                    : package.latestVersionNumber;
          _normalizePackageForUserSave(
            package,
            actor: actor,
            markUnsynced: true,
          );
          await isar.templatePackages.put(package);
        }
      }
    });
  }

  @override
  Future<void> retireVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    _requireTemplateGovernor(actor, 'retire template versions');
    if (!record.isPublished) {
      throw StateError('Only published template versions can be retired.');
    }

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.retired
      ..retiredByUid = actor.uid
      ..retiredByName = actor.name
      ..retiredAt = now
      ..retireReason = reason
      ..updatedAt = now;
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.retired,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    );

    await isar.writeTxn(() async {
      await isar.templateVersions.put(record);
      await isar.templatePublishAudits.put(audit);

      final packageId = record.packageFirestoreId;
      if (packageId != null) {
        final package =
            await isar.templatePackages
                .filter()
                .firestoreIdEqualTo(packageId)
                .findFirst();
        if (package?.activeVersionFirestoreId == record.firestoreId) {
          package!.activeVersionFirestoreId = null;
          _normalizePackageForUserSave(
            package,
            actor: actor,
            markUnsynced: true,
          );
          await isar.templatePackages.put(package);
        }
      }
    });
  }

  @override
  Future<void> saveAudit(TemplatePublishAudit record) async {
    final now = DateTime.now();
    record
      ..firestoreId ??= _newAuditFirestoreId()
      ..performedAt = _readAuditPerformedAtSafely(record) ?? now
      ..updatedAt = now
      ..isSynced = false;
    await isar.writeTxn(() => isar.templatePublishAudits.put(record));
  }

  @override
  Future<List<TemplatePackage>> getAllPackages() async {
    final records =
        await isar.templatePackages.filter().isDeletedEqualTo(false).findAll();
    records.sort((a, b) => a.title.compareTo(b.title));
    return records;
  }

  @override
  Stream<List<TemplatePackage>> watchPackages({int? limit}) {
    if (limit != null) {
      return isar.templatePackages
          .filter()
          .isDeletedEqualTo(false)
          .sortByTitle()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.templatePackages
        .filter()
        .isDeletedEqualTo(false)
        .sortByTitle()
        .watch(fireImmediately: true);
  }

  @override
  Future<TemplatePackage?> getPackageById(dynamic id) async {
    return isar.templatePackages.get(id as int);
  }

  @override
  Future<TemplatePackage?> getPackageByFirestoreId(String firestoreId) async {
    return isar.templatePackages
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  ) async {
    final records =
        await isar.templateVersions
            .filter()
            .packageFirestoreIdEqualTo(packageFirestoreId)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return records;
  }

  @override
  Stream<List<TemplateVersion>> watchVersionsForPackage(
    String packageFirestoreId,
  ) {
    return isar.templateVersions
        .filter()
        .packageFirestoreIdEqualTo(packageFirestoreId)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((records) {
          records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
          return records;
        });
  }

  @override
  Future<TemplateVersion?> getVersionById(dynamic id) async {
    return isar.templateVersions.get(id as int);
  }

  @override
  Future<TemplateVersion?> getVersionByFirestoreId(String firestoreId) async {
    return isar.templateVersions
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsForVersion(
    String versionFirestoreId,
  ) async {
    final records =
        await isar.templatePublishAudits
            .filter()
            .versionFirestoreIdEqualTo(versionFirestoreId)
            .findAll();
    records.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return records;
  }

  @override
  Future<TemplatePublishAudit?> getAuditByFirestoreId(
    String firestoreId,
  ) async {
    return isar.templatePublishAudits
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    return isar.templatePackages.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markPackagesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templatePackages.getAll(
            ids,
          )).whereType<TemplatePackage>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templatePackages.putAll(records);
    });
  }

  @override
  Future<void> markPackagesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templatePackages.getAll(
            byId.keys.toList(),
          )).whereType<TemplatePackage>().toList();
      final unchanged = <TemplatePackage>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.templatePackages.putAll(unchanged);
    });
  }

  @override
  Future<void> insertPackageFromRemote(TemplatePackage remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templatePackages.put(remote));
  }

  @override
  Future<void> updatePackageFromRemote(TemplatePackage remote) async {
    if (remote.firestoreId == null) return;
    await isar.writeTxn(() async {
      final local = await getPackageByFirestoreId(remote.firestoreId!);
      if (local == null) return;
      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced template package against remote tombstone in updatePackageFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }
      }
      if (!local.isSynced && remote.updatedAt.isBefore(local.updatedAt)) return;
      remote
        ..id = local.id
        ..isSynced = true;
      await isar.templatePackages.put(remote);
    });
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromPackageRemote(
    TemplatePackage remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await getPackageByFirestoreId(remote.firestoreId!);
      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced template package against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remote.deletedAt ?? DateTime.now()
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.templatePackages.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async {
    return isar.templateVersions.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markVersionsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templateVersions.getAll(
            ids,
          )).whereType<TemplateVersion>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templateVersions.putAll(records);
    });
  }

  @override
  Future<void> markVersionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templateVersions.getAll(
            byId.keys.toList(),
          )).whereType<TemplateVersion>().toList();
      final unchanged = <TemplateVersion>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.templateVersions.putAll(unchanged);
    });
  }

  @override
  Future<void> insertVersionFromRemote(TemplateVersion remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templateVersions.put(remote));
  }

  @override
  Future<void> updateVersionFromRemote(TemplateVersion remote) async {
    if (remote.firestoreId == null) return;
    await isar.writeTxn(() async {
      final local = await getVersionByFirestoreId(remote.firestoreId!);
      if (local == null) return;
      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced template version against remote tombstone in updateVersionFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }
      }
      if (!local.isSynced && remote.updatedAt.isBefore(local.updatedAt)) return;
      remote
        ..id = local.id
        ..isSynced = true;
      await isar.templateVersions.put(remote);
    });
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromVersionRemote(
    TemplateVersion remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await getVersionByFirestoreId(remote.firestoreId!);
      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced template version against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remote.deletedAt ?? DateTime.now()
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.templateVersions.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async {
    return isar.templatePublishAudits.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markAuditsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templatePublishAudits.getAll(
            ids,
          )).whereType<TemplatePublishAudit>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templatePublishAudits.putAll(records);
    });
  }

  @override
  Future<void> markAuditsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templatePublishAudits.getAll(
            byId.keys.toList(),
          )).whereType<TemplatePublishAudit>().toList();
      final unchanged = <TemplatePublishAudit>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) {
        await isar.templatePublishAudits.putAll(unchanged);
      }
    });
  }

  @override
  Future<void> insertAuditFromRemote(TemplatePublishAudit remote) async {
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templatePublishAudits.put(remote));
  }

  @override
  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplatePackageResult(records: const [], lastDoc: null);
  }

  @override
  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateVersionResult(records: const [], lastDoc: null);
  }

  @override
  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateAuditResult(records: const [], lastDoc: null);
  }

  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplatePackage>[];
    for (final id in ids) {
      final record = await getPackageByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertPackages(List<TemplatePackage> records) async {
    await isar.writeTxn(() => isar.templatePackages.putAll(records));
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplateVersion>[];
    for (final id in ids) {
      final record = await getVersionByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertVersions(List<TemplateVersion> records) async {
    await isar.writeTxn(() => isar.templateVersions.putAll(records));
  }

  @override
  Future<void> createRemoteTemplateVersionDraftReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData,
  ) {
    throw UnsupportedError(
      'createRemoteTemplateVersionDraftReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<void> applyRemoteTemplateVersionPublishReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> publishData,
  ) {
    throw UnsupportedError(
      'applyRemoteTemplateVersionPublishReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplatePublishAudit>[];
    for (final id in ids) {
      final record = await getAuditByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records) async {
    await isar.writeTxn(() => isar.templatePublishAudits.putAll(records));
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class FirestoreTemplateGovernanceRepository
    implements TemplateGovernanceRepository {
  final _packages = FirebaseFirestore.instance.collection('template_packages');
  final _versions = FirebaseFirestore.instance.collection('template_versions');
  final _audits = FirebaseFirestore.instance.collection(
    'template_publish_audits',
  );

  @override
  Future<void> savePackage(
    TemplatePackage record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template packages');
    _normalizePackageForUserSave(record, actor: actor, markUnsynced: false);
    await _packages
        .doc(record.firestoreId)
        .set(record.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveVersion(
    TemplateVersion record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions are editable.');
    }
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);
    await _versions
        .doc(record.firestoreId)
        .set(record.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> publishVersion(
    TemplateVersion record, {
    required AppUser actor,
    String? reason,
  }) async {
    _requireTemplateGovernor(actor, 'publish template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions can be published.');
    }
    if (record.firestoreId != null && !record.isSynced) {
      throw StateError(
        'A saved TemplateVersion draft must sync successfully before it can be published.',
      );
    }

    _validateTemplateVersionSnapshotForPublish(record);

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.published
      ..publishedByUid = actor.uid
      ..publishedByName = actor.name
      ..publishedAt = now
      ..updatedAt = now;
    record.refreshContentHash();
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.published,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    )..isSynced = true;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final packageId = record.packageFirestoreId;
      DocumentReference<Map<String, dynamic>>? packageRef;
      DocumentSnapshot<Map<String, dynamic>>? packageSnap;

      if (packageId != null) {
        packageRef = _packages.doc(packageId);
        packageSnap = await txn.get(packageRef);
      }

      txn.set(
        _versions.doc(record.firestoreId),
        record.toMap(),
        SetOptions(merge: true),
      );
      txn.set(
        _audits.doc(audit.firestoreId),
        audit.toMap(),
        SetOptions(merge: true),
      );

      if (packageRef != null) {
        final currentLatest = packageSnap?.data()?['latestVersionNumber'];
        final currentLatestNumber = currentLatest is int ? currentLatest : 0;
        final nextLatestNumber =
            record.versionNumber > currentLatestNumber
                ? record.versionNumber
                : currentLatestNumber;

        txn.set(packageRef, {
          'activeVersionFirestoreId': record.firestoreId,
          'latestVersionNumber': nextLatestNumber,
          'updatedByUid': actor.uid,
          'updatedByName': actor.name,
          'updatedAt': now.toIso8601String(),
          'version': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> retireVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    _requireTemplateGovernor(actor, 'retire template versions');
    if (!record.isPublished) {
      throw StateError('Only published template versions can be retired.');
    }

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.retired
      ..retiredByUid = actor.uid
      ..retiredByName = actor.name
      ..retiredAt = now
      ..retireReason = reason
      ..updatedAt = now;
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.retired,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    )..isSynced = true;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final packageId = record.packageFirestoreId;
      DocumentReference<Map<String, dynamic>>? packageRef;
      DocumentSnapshot<Map<String, dynamic>>? packageSnap;

      if (packageId != null) {
        packageRef = _packages.doc(packageId);
        packageSnap = await txn.get(packageRef);
      }

      txn.set(
        _versions.doc(record.firestoreId),
        record.toMap(),
        SetOptions(merge: true),
      );
      txn.set(
        _audits.doc(audit.firestoreId),
        audit.toMap(),
        SetOptions(merge: true),
      );

      final isActiveVersion =
          packageSnap?.data()?['activeVersionFirestoreId'] ==
          record.firestoreId;
      if (packageRef != null && isActiveVersion) {
        txn.set(packageRef, {
          'activeVersionFirestoreId': null,
          'updatedByUid': actor.uid,
          'updatedByName': actor.name,
          'updatedAt': now.toIso8601String(),
          'version': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> saveAudit(TemplatePublishAudit record) async {
    record.firestoreId ??= _newAuditFirestoreId();
    record.isSynced = true;
    await _audits
        .doc(record.firestoreId)
        .set(record.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<TemplatePackage>> getAllPackages() async {
    final snap = await _packages.where('isDeleted', isEqualTo: false).get();
    final records =
        snap.docs
            .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
            .toList();
    records.sort((a, b) => a.title.compareTo(b.title));
    return records;
  }

  @override
  Stream<List<TemplatePackage>> watchPackages({int? limit}) {
    Query<Map<String, dynamic>> query = _packages
        .where('isDeleted', isEqualTo: false)
        .orderBy('title');
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<TemplatePackage?> getPackageById(dynamic id) async {
    final doc = await _packages.doc(id as String).get();
    if (!doc.exists) return null;
    return TemplatePackage.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<TemplatePackage?> getPackageByFirestoreId(String firestoreId) async {
    final doc = await _packages.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplatePackage.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  ) async {
    final snap =
        await _versions
            .where('packageFirestoreId', isEqualTo: packageFirestoreId)
            .where('isDeleted', isEqualTo: false)
            .get();
    final records =
        snap.docs
            .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
            .toList();
    records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return records;
  }

  @override
  Stream<List<TemplateVersion>> watchVersionsForPackage(
    String packageFirestoreId,
  ) {
    return _versions
        .where('packageFirestoreId', isEqualTo: packageFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final records =
              snap.docs
                  .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
                  .toList();
          records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
          return records;
        });
  }

  @override
  Future<TemplateVersion?> getVersionById(dynamic id) async {
    final doc = await _versions.doc(id as String).get();
    if (!doc.exists) return null;
    return TemplateVersion.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<TemplateVersion?> getVersionByFirestoreId(String firestoreId) async {
    final doc = await _versions.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplateVersion.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsForVersion(
    String versionFirestoreId,
  ) async {
    final snap =
        await _audits
            .where('versionFirestoreId', isEqualTo: versionFirestoreId)
            .get();
    final records =
        snap.docs
            .map((doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id))
            .toList();
    records.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return records;
  }

  @override
  Future<TemplatePublishAudit?> getAuditByFirestoreId(
    String firestoreId,
  ) async {
    final doc = await _audits.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplatePublishAudit.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async => [];

  @override
  Future<void> markPackagesSynced(List<int> ids) async {}

  @override
  Future<void> markPackagesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertPackageFromRemote(TemplatePackage remote) async {}

  @override
  Future<void> updatePackageFromRemote(TemplatePackage remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromPackageRemote(
    TemplatePackage remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async => [];

  @override
  Future<void> markVersionsSynced(List<int> ids) async {}

  @override
  Future<void> markVersionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertVersionFromRemote(TemplateVersion remote) async {}

  @override
  Future<void> updateVersionFromRemote(TemplateVersion remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromVersionRemote(
    TemplateVersion remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async => [];

  @override
  Future<void> markAuditsSynced(List<int> ids) async {}

  @override
  Future<void> markAuditsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertAuditFromRemote(TemplatePublishAudit remote) async {}

  @override
  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _packages.orderBy('updatedAt');
    if (since != null) {
      query = query.where('updatedAt', isGreaterThan: since.toIso8601String());
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplatePackageResult(
      records:
          snap.docs
              .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _versions.orderBy('updatedAt');
    if (since != null) {
      query = query.where('updatedAt', isGreaterThan: since.toIso8601String());
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplateVersionResult(
      records:
          snap.docs
              .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _audits.orderBy('updatedAt');
    if (since != null) {
      query = query.where('updatedAt', isGreaterThan: since.toIso8601String());
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplateAuditResult(
      records:
          snap.docs
              .map((doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplatePackage>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _packages.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => TemplatePackage.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertPackages(List<TemplatePackage> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _packages.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplateVersion>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _versions.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => TemplateVersion.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertVersions(List<TemplateVersion> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _versions.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<void> createRemoteTemplateVersionDraftReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'createRemoteTemplateVersionDraftReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final ref = _versions.doc(id);
      final snap = await txn.get(ref);
      if (snap.exists) {
        throw StateError(
          'TemplateVersion draft replay refused to overwrite existing remote document: $id',
        );
      }
      txn.set(ref, draftData);
    });
  }

  @override
  Future<void> applyRemoteTemplateVersionPublishReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> publishData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteTemplateVersionPublishReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await _versions.doc(id).set(publishData, SetOptions(merge: true));
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplatePublishAudit>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _audits.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map(
          (doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id),
        ),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _audits.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final isarTemplateGovernanceRepo = Provider<IsarTemplateGovernanceRepository>(
  (ref) => IsarTemplateGovernanceRepository(),
);

final firestoreTemplateGovernanceRepo =
    Provider<FirestoreTemplateGovernanceRepository>(
      (ref) => FirestoreTemplateGovernanceRepository(),
    );

final templateGovernanceRepositoryProvider =
    Provider<TemplateGovernanceRepository>((ref) {
      return kIsWeb
          ? ref.watch(firestoreTemplateGovernanceRepo)
          : ref.watch(isarTemplateGovernanceRepo);
    });

final templatePackagesProvider = StreamProvider<List<TemplatePackage>>((ref) {
  return ref.watch(templateGovernanceRepositoryProvider).watchPackages();
});

final packageVersionsProvider =
    StreamProvider.family<List<TemplateVersion>, String>((
      ref,
      packageFirestoreId,
    ) {
      return ref
          .watch(templateGovernanceRepositoryProvider)
          .watchVersionsForPackage(packageFirestoreId);
    });
