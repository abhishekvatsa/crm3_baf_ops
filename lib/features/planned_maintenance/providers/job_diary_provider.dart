// FILE: lib/features/planned_maintenance/providers/job_diary_provider.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../../core/persistence/app_database.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../data/job_diary_model.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';

part 'job_diary_provider.local.dart';
part 'job_diary_provider.remote.dart';

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

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

DateTime? _readCreatedAtSafely(JobDiaryEntry entry) {
  try {
    return entry.createdAt;
  } catch (_) {
    return null;
  }
}

String? _readNoteSafely(JobDiaryEntry entry) {
  try {
    return entry.note;
  } catch (_) {
    return null;
  }
}

String _newDiaryFirestoreId() {
  return FirebaseFirestore.instance.collection('job_diary_entries').doc().id;
}

void _normalizeDiaryEntryForUserSave(
  JobDiaryEntry entry, {
  required bool markUnsynced,
  bool preserveCreatedAt = true,
  bool bumpVersion = false,
}) {
  final now = DateTime.now();

  entry.firestoreId ??= _newDiaryFirestoreId();
  if (bumpVersion) {
    entry.version += 1;
  }

  final existingCreatedAt = _readCreatedAtSafely(entry);
  entry.createdAt =
      preserveCreatedAt && existingCreatedAt != null ? existingCreatedAt : now;

  entry
    ..jobExecutionFirestoreId = _cleanOptionalText(
      entry.jobExecutionFirestoreId,
    )
    ..moduleInstanceFirestoreId = _cleanOptionalText(
      entry.moduleInstanceFirestoreId,
    )
    ..templateFirestoreId = _cleanOptionalText(entry.templateFirestoreId)
    ..templateName = _cleanOptionalText(entry.templateName)
    ..functionalSection = _cleanOptionalText(entry.functionalSection)
    ..componentGroup = _cleanOptionalText(entry.componentGroup)
    ..targetRef = _cleanOptionalText(entry.targetRef)
    ..procedureRef = _cleanOptionalText(entry.procedureRef)
    ..tags = _cleanStringList(entry.tags)
    ..title = _cleanOptionalText(entry.title)
    ..note = _cleanRequiredText(_readNoteSafely(entry), 'Progress note')
    ..actionTaken = _cleanOptionalText(entry.actionTaken)
    ..pendingIssue = _cleanOptionalText(entry.pendingIssue)
    ..createdByUid = _cleanOptionalText(entry.createdByUid)
    ..createdByName = _cleanOptionalText(entry.createdByName)
    ..updatedByUid = _cleanOptionalText(entry.updatedByUid)
    ..updatedByName = _cleanOptionalText(entry.updatedByName)
    ..deletedByUid = _cleanOptionalText(entry.deletedByUid)
    ..deletedByName = _cleanOptionalText(entry.deletedByName)
    ..deleteReason = _cleanOptionalText(entry.deleteReason)
    ..metadataJson = _cleanOptionalText(entry.metadataJson)
    ..updatedAt = now;

  if (_cleanOptionalText(entry.jobExecutionFirestoreId) != null) {
    entry.jobExecutionLocalId = null;
  }
  if (_cleanOptionalText(entry.moduleInstanceFirestoreId) != null) {
    entry.moduleInstanceLocalId = null;
  }

  if (entry.kind == JobDiaryKind.blocker) {
    entry.isBlocker = true;
    entry.blockerStatus ??= JobBlockerStatus.open;
  }

  if (entry.kind == JobDiaryKind.handover) {
    entry.isHandover = true;
  }

  if (!entry.isBlocker) {
    entry.blockerStatus = null;
  }

  if (markUnsynced) {
    entry.isSynced = false;
  }
}

void _copyRemoteEntryIntoLocal(JobDiaryEntry local, JobDiaryEntry remote) {
  local
    ..firestoreId = remote.firestoreId
    ..jobExecutionFirestoreId = remote.jobExecutionFirestoreId
    ..jobExecutionLocalId = null
    ..moduleInstanceFirestoreId = remote.moduleInstanceFirestoreId
    ..moduleInstanceLocalId = null
    ..assetType = remote.assetType
    ..assetNumber = remote.assetNumber
    ..chargeNoAtEvent = remote.chargeNoAtEvent
    ..templateFirestoreId = remote.templateFirestoreId
    ..templateName = remote.templateName
    ..kind = remote.kind
    ..discipline = remote.discipline
    ..severity = remote.severity
    ..blockerStatus = remote.blockerStatus
    ..isBlocker = remote.isBlocker
    ..isHandover = remote.isHandover
    ..functionalSection = remote.functionalSection
    ..componentGroup = remote.componentGroup
    ..targetRef = remote.targetRef
    ..procedureRef = remote.procedureRef
    ..tags = List<String>.from(remote.tags)
    ..title = remote.title
    ..note = remote.note
    ..actionTaken = remote.actionTaken
    ..pendingIssue = remote.pendingIssue
    ..requiresFollowUp = remote.requiresFollowUp
    ..createdByUid = remote.createdByUid
    ..createdByName = remote.createdByName
    ..createdAt = remote.createdAt
    ..updatedByUid = remote.updatedByUid
    ..updatedByName = remote.updatedByName
    ..updatedAt = remote.updatedAt
    ..isDeleted = remote.isDeleted
    ..deletedAt = remote.deletedAt
    ..deletedByUid = remote.deletedByUid
    ..deletedByName = remote.deletedByName
    ..deleteReason = remote.deleteReason
    ..version = remote.version
    ..metadataJson = remote.metadataJson
    ..isSynced = true;
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedDiaryResult {
  final List<JobDiaryEntry> records;
  final DocumentSnapshot? lastDoc;

  PaginatedDiaryResult({required this.records, this.lastDoc});
}

class JobDiaryQueryKey {
  final String? jobExecutionFirestoreId;
  final int? jobExecutionLocalId;
  final int? limit;

  const JobDiaryQueryKey({
    this.jobExecutionFirestoreId,
    this.jobExecutionLocalId,
    this.limit,
  });

  @override
  bool operator ==(Object other) {
    return other is JobDiaryQueryKey &&
        other.jobExecutionFirestoreId == jobExecutionFirestoreId &&
        other.jobExecutionLocalId == jobExecutionLocalId &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      Object.hash(jobExecutionFirestoreId, jobExecutionLocalId, limit);
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class JobDiaryRepository {
  Future<void> saveEntry(
    JobDiaryEntry entry, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<List<JobDiaryEntry>> getEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  });

  Stream<List<JobDiaryEntry>> watchEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  });

  Future<void> softDeleteEntry(dynamic id, {AuditContext? auditContext});

  Future<JobDiaryEntry?> getEntryByFirestoreId(String firestoreId);
  Future<List<JobDiaryEntry>> getUnsyncedEntries();
  Future<void> markEntriesSynced(List<int> ids);
  Future<void> markEntriesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> insertEntryFromRemote(JobDiaryEntry remote);
  Future<void> updateEntryFromRemote(JobDiaryEntry remote);
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobDiaryEntry remote,
  );

  Future<PaginatedDiaryResult> getUpdatedEntries({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<List<JobDiaryEntry>> getEntriesByFirestoreIds(List<String> ids);
  Future<void> batchUpsertEntries(List<JobDiaryEntry> records);
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

final isarJobDiaryRepoProvider = Provider<IsarJobDiaryRepository>((ref) {
  return IsarJobDiaryRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final firestoreJobDiaryRepoProvider = Provider<FirestoreJobDiaryRepository>((
  ref,
) {
  return FirestoreJobDiaryRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final jobDiaryRepositoryProvider = Provider<JobDiaryRepository>((ref) {
  return kIsWeb
      ? ref.watch(firestoreJobDiaryRepoProvider)
      : ref.watch(isarJobDiaryRepoProvider);
});

final jobDiaryEntriesProvider =
    StreamProvider.family<List<JobDiaryEntry>, JobDiaryQueryKey>((ref, key) {
      return ref
          .watch(jobDiaryRepositoryProvider)
          .watchEntriesForJob(
            jobExecutionFirestoreId: key.jobExecutionFirestoreId,
            jobExecutionLocalId: key.jobExecutionLocalId,
            limit: key.limit,
          );
    });
