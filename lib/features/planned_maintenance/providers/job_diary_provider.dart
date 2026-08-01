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

class IsarJobDiaryRepository implements JobDiaryRepository {
  final AuditRepository _auditRepo;

  IsarJobDiaryRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  @override
  Future<void> saveEntry(
    JobDiaryEntry entry, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final isCreate = entry.id == Isar.autoIncrement;
    if (isCreate) {
      if (!actor.canCreateJobDiaryEntry) {
        throw StateError('Not authorized to create planned-job diary entries.');
      }
    } else if (!actor.canEditJobDiaryEntry(createdByUid: entry.createdByUid)) {
      throw StateError('Not authorized to edit this planned-job diary entry.');
    }
    _normalizeDiaryEntryForUserSave(
      entry,
      markUnsynced: true,
      bumpVersion: !isCreate,
    );

    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      if (!isCreate && entry.id != Isar.autoIncrement) {
        final existing = await isar.jobDiaryEntrys.get(entry.id);
        beforeSnapshot = existing?.toAuditMap();
      }

      await isar.jobDiaryEntrys.put(entry);
      afterSnapshot = entry.toAuditMap();
      entityId = entry.firestoreId ?? entry.id.toString();
    });

    if (auditContext != null && afterSnapshot != null && entityId != null) {
      final action =
          beforeSnapshot == null ? AuditAction.create : AuditAction.update;
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_diary_entry',
            entityId: entityId!,
            action: action,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ??
                  (action == AuditAction.create
                      ? 'Added planned-maintenance diary entry'
                      : 'Updated planned-maintenance diary entry'),
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<List<JobDiaryEntry>> getEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  }) async {
    final entries =
        await _baseJobQuery(
          jobExecutionFirestoreId: jobExecutionFirestoreId,
          jobExecutionLocalId: jobExecutionLocalId,
        ).findAll();

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit != null && entries.length > limit) {
      return entries.take(limit).toList();
    }
    return entries;
  }

  @override
  Stream<List<JobDiaryEntry>> watchEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  }) {
    return _baseJobQuery(
      jobExecutionFirestoreId: jobExecutionFirestoreId,
      jobExecutionLocalId: jobExecutionLocalId,
    ).watch(fireImmediately: true).map((entries) {
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit != null && entries.length > limit) {
        return entries.take(limit).toList();
      }
      return entries;
    });
  }

  QueryBuilder<JobDiaryEntry, JobDiaryEntry, QAfterFilterCondition>
  _baseJobQuery({String? jobExecutionFirestoreId, int? jobExecutionLocalId}) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);

    if (cleanedFirestoreId != null) {
      return isar.jobDiaryEntrys
          .filter()
          .jobExecutionFirestoreIdEqualTo(cleanedFirestoreId)
          .and()
          .isDeletedEqualTo(false);
    }

    if (jobExecutionLocalId != null) {
      return isar.jobDiaryEntrys
          .filter()
          .jobExecutionLocalIdEqualTo(jobExecutionLocalId)
          .and()
          .isDeletedEqualTo(false);
    }

    return isar.jobDiaryEntrys
        .filter()
        .firestoreIdEqualTo('__no_matching_job_diary_entry__')
        .and()
        .isDeletedEqualTo(false);
  }

  @override
  Future<void> softDeleteEntry(dynamic id, {AuditContext? auditContext}) async {
    final entryId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final entry = await isar.jobDiaryEntrys.get(entryId);
      if (entry == null || entry.isDeleted) return;

      beforeSnapshot = entry.toAuditMap();
      final now = DateTime.now();

      entry
        ..isDeleted = true
        ..deletedAt = now
        ..updatedAt = now
        ..version += 1
        ..isSynced = false;

      if (auditContext != null) {
        entry
          ..deletedByUid = auditContext.performedByUid
          ..deletedByName = auditContext.performedByName
          ..deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
      }

      await isar.jobDiaryEntrys.put(entry);
      afterSnapshot = entry.toAuditMap();
      entityId = entry.firestoreId ?? entry.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_diary_entry',
            entityId: entityId!,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ??
                  'Deleted planned-maintenance diary entry',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<JobDiaryEntry?> getEntryByFirestoreId(String firestoreId) async {
    return isar.jobDiaryEntrys
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<JobDiaryEntry>> getUnsyncedEntries() async {
    return isar.jobDiaryEntrys.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markEntriesSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    await isar.writeTxn(() async {
      final entries = await isar.jobDiaryEntrys.getAll(ids);
      for (final entry in entries.whereType<JobDiaryEntry>()) {
        entry.isSynced = true;
        await isar.jobDiaryEntrys.put(entry);
      }
    });
  }

  @override
  Future<void> markEntriesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final entries = await isar.jobDiaryEntrys.getAll(byId.keys.toList());
      for (final entry in entries.whereType<JobDiaryEntry>()) {
        final pushed = byId[entry.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: entry.version,
          currentUpdatedAt: entry.updatedAt,
        )) {
          continue;
        }
        entry.isSynced = true;
        await isar.jobDiaryEntrys.put(entry);
      }
    });
  }

  @override
  Future<void> insertEntryFromRemote(JobDiaryEntry remote) async {
    remote
      ..jobExecutionLocalId = null
      ..moduleInstanceLocalId = null
      ..isSynced = true;
    await isar.writeTxn(() => isar.jobDiaryEntrys.put(remote));
  }

  @override
  Future<void> updateEntryFromRemote(JobDiaryEntry remote) async {
    if (remote.firestoreId == null) return;

    await isar.writeTxn(() async {
      final local =
          await isar.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced diary entry against remote tombstone in updateEntryFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          _copyRemoteEntryIntoLocal(local, remote);
          await isar.jobDiaryEntrys.put(local);
        }
        return;
      }

      final isLocalUnsynced = !local.isSynced;
      final isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      _copyRemoteEntryIntoLocal(local, remote);
      await isar.jobDiaryEntrys.put(local);
    });
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobDiaryEntry remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced diary entry against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      _copyRemoteEntryIntoLocal(local, remote);
      await isar.jobDiaryEntrys.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<PaginatedDiaryResult> getUpdatedEntries({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedDiaryResult(records: [], lastDoc: null);
  }

  @override
  Future<List<JobDiaryEntry>> getEntriesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <JobDiaryEntry>[];
    for (final firestoreId in ids) {
      final entry =
          await isar.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();
      if (entry != null) results.add(entry);
    }
    return results;
  }

  @override
  Future<void> batchUpsertEntries(List<JobDiaryEntry> records) async {
    if (records.isEmpty) return;
    await isar.writeTxn(() async {
      for (final record in records) {
        await isar.jobDiaryEntrys.put(record);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class FirestoreJobDiaryRepository implements JobDiaryRepository {
  final AuditRepository _auditRepo;

  FirestoreJobDiaryRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final _entries = FirebaseFirestore.instance.collection('job_diary_entries');

  @override
  Future<void> saveEntry(
    JobDiaryEntry entry, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final existing =
        entry.firestoreId == null
            ? null
            : await _entries.doc(entry.firestoreId).get();
    final isCreate = existing == null || !existing.exists;
    if (isCreate) {
      if (!actor.canCreateJobDiaryEntry) {
        throw StateError('Not authorized to create planned-job diary entries.');
      }
    } else if (!actor.canEditJobDiaryEntry(createdByUid: entry.createdByUid)) {
      throw StateError('Not authorized to edit this planned-job diary entry.');
    }
    _normalizeDiaryEntryForUserSave(
      entry,
      markUnsynced: false,
      preserveCreatedAt: true,
      bumpVersion: !isCreate,
    );

    entry.isSynced = true;
    await _entries
        .doc(entry.firestoreId)
        .set(entry.toMap(), SetOptions(merge: true));

    if (auditContext != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_diary_entry',
            entityId: entry.firestoreId!,
            action: AuditAction.create,
            context: auditContext.copyWith(
              after: entry.toAuditMap(),
              summary:
                  auditContext.summary ??
                  'Saved planned-maintenance diary entry',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<List<JobDiaryEntry>> getEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) return [];

    Query<Map<String, dynamic>> query = _entries
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
    return snap.docs
        .map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<JobDiaryEntry>> watchEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) {
      return Stream<List<JobDiaryEntry>>.value(const []);
    }

    Query<Map<String, dynamic>> query = _entries
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) query = query.limit(limit);

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> softDeleteEntry(dynamic id, {AuditContext? auditContext}) async {
    final docId = id as String;
    final doc = await _entries.doc(docId).get();
    if (!doc.exists || doc.data() == null) return;

    final before = JobDiaryEntry.fromMap(doc.data()!, doc.id);
    final now = DateTime.now();

    final updateMap = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'version': FieldValue.increment(1),
      'isSynced': true,
    };

    if (auditContext != null) {
      updateMap['deletedByUid'] = auditContext.performedByUid;
      updateMap['deletedByName'] = auditContext.performedByName;
      updateMap['deleteReason'] =
          auditContext.reason?.name ?? auditContext.reasonNotes;
    }

    await _entries.doc(docId).update(updateMap);

    if (auditContext != null) {
      final afterDoc = await _entries.doc(docId).get();
      final after =
          afterDoc.data() != null
              ? JobDiaryEntry.fromMap(afterDoc.data()!, afterDoc.id)
              : null;

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_diary_entry',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: before.toAuditMap(),
              after: after?.toAuditMap(),
              summary:
                  auditContext.summary ??
                  'Deleted planned-maintenance diary entry',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<JobDiaryEntry?> getEntryByFirestoreId(String firestoreId) async {
    final doc = await _entries.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;
    return JobDiaryEntry.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<JobDiaryEntry>> getUnsyncedEntries() async => [];

  @override
  Future<void> markEntriesSynced(List<int> ids) async {}

  @override
  Future<void> markEntriesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertEntryFromRemote(JobDiaryEntry remote) async {}

  @override
  Future<void> updateEntryFromRemote(JobDiaryEntry remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobDiaryEntry remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<PaginatedDiaryResult> getUpdatedEntries({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-diary pull has no server upper bound.',
        reasonCode: 'job-diary-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _entries,
      afterInclusive: since,
      throughInclusive: through,
    );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.limit(limit).get();
    return PaginatedDiaryResult(
      records:
          snap.docs
              .map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<JobDiaryEntry>> getEntriesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final results = <JobDiaryEntry>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _entries.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertEntries(List<JobDiaryEntry> records) async {
    if (records.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    for (var i = 0; i < records.length; i += 500) {
      final chunk = records.sublist(
        i,
        i + 500 > records.length ? records.length : i + 500,
      );
      final batch = firestore.batch();

      for (final record in chunk) {
        if (_cleanOptionalText(record.firestoreId) == null) continue;
        batch.set(
          _entries.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
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
