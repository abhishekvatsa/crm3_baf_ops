// FILE: lib/features/planned_maintenance/providers/template_governance_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../../core/persistence/app_database.dart';
import '../../auth/data/user_model.dart';
import '../data/template_governance_model.dart';
import '../domain/template_version_snapshot_contract.dart';
import '../domain/template_publication_readiness.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/global_pull_protocol.dart';

part 'template_governance_provider.local.dart';
part 'template_governance_provider.remote.dart';

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

void _applyTemplateVersionDraftLifecycleTransition(
  TemplateVersion record, {
  required TemplateVersionStatus status,
  required AppUser actor,
  required bool markUnsynced,
}) {
  final now = DateTime.now();
  record
    ..status = status
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..updatedAt = now
    ..version += 1;
  record.refreshContentHash();
  if (markUnsynced) {
    record.isSynced = false;
  }
}

void _copyTemplateVersionLifecycleState(
  TemplateVersion target,
  TemplateVersion source, {
  required bool isSynced,
}) {
  target
    ..status = source.status
    ..contentHash = source.contentHash
    ..closureReviewConfirmed = source.closureReviewConfirmed
    ..closureCriticalModuleCount = source.closureCriticalModuleCount
    ..closureReviewConfirmedByUid = source.closureReviewConfirmedByUid
    ..closureReviewConfirmedByName = source.closureReviewConfirmedByName
    ..closureReviewConfirmedAt = source.closureReviewConfirmedAt
    ..updatedByUid = source.updatedByUid
    ..updatedByName = source.updatedByName
    ..updatedAt = source.updatedAt
    ..version = source.version
    ..isSynced = isSynced;
}

TemplatePublishAudit _newAudit({
  required TemplatePublishAuditAction action,
  required AppUser actor,
  required TemplateVersion version,
  String? reason,
  String? beforeHash,
  String? afterHash,
  String? firestoreId,
}) {
  final now = DateTime.now();
  return TemplatePublishAudit()
    ..firestoreId = firestoreId ?? _newAuditFirestoreId()
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

  Future<void> archiveDraftVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  });

  Future<void> restoreArchivedDraftVersion(
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromAuditRemote(
    TemplatePublishAudit remote,
  );

  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    DateTime? through,
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

  /// Updates an existing remote draft to the final locally-saved draft payload
  /// before a collapsed draft→archive lifecycle is replayed.
  ///
  /// This is deliberately separate from draft creation: it must never create a
  /// missing remote document and remains subject to the normal draft→draft
  /// Firestore transition contract.
  Future<void> applyRemoteTemplateVersionDraftUpdateReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData, {
    required int expectedDraftVersion,
  });

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

  /// Applies the second replay step for an offline draft archived before its
  /// draft predecessor reached Firestore.
  Future<void> applyRemoteTemplateVersionArchiveReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> archiveData, {
    required int expectedDraftVersion,
  });

  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(List<String> ids);
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records);
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
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

class TemplatePublicationReadinessQuery {
  final String packageFirestoreId;
  final String versionFirestoreId;

  const TemplatePublicationReadinessQuery({
    required this.packageFirestoreId,
    required this.versionFirestoreId,
  });

  @override
  bool operator ==(Object other) {
    return other is TemplatePublicationReadinessQuery &&
        other.packageFirestoreId == packageFirestoreId &&
        other.versionFirestoreId == versionFirestoreId;
  }

  @override
  int get hashCode => Object.hash(packageFirestoreId, versionFirestoreId);
}

/// Reloads the assignment authority triad from the active repository and
/// evaluates it through the pure domain contract.
///
/// This provider deliberately does not trust the package/version objects that
/// happen to be mounted in the assignment screen. A submit-time caller should
/// still re-read this provider/repository state immediately before invoking the
/// server assignment callable.
final templatePublicationReadinessProvider = FutureProvider.autoDispose.family<
  TemplatePublicationReadinessDecision,
  TemplatePublicationReadinessQuery
>((ref, query) async {
  final repository = ref.watch(templateGovernanceRepositoryProvider);
  final package = await repository.getPackageByFirestoreId(
    query.packageFirestoreId,
  );
  final version = await repository.getVersionByFirestoreId(
    query.versionFirestoreId,
  );
  final audits = await repository.getAuditsForVersion(query.versionFirestoreId);
  return evaluateTemplatePublicationReadiness(
    package: package,
    version: version,
    audits: audits,
  );
});
