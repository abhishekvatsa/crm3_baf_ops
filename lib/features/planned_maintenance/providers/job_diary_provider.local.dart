part of 'job_diary_provider.dart';

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
    bool includeDeleted = false,
  }) async {
    final entries =
        await _baseJobQuery(
          jobExecutionFirestoreId: jobExecutionFirestoreId,
          jobExecutionLocalId: jobExecutionLocalId,
          includeDeleted: includeDeleted,
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
  _baseJobQuery({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    bool includeDeleted = false,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);

    if (cleanedFirestoreId != null) {
      final query = isar.jobDiaryEntrys.filter().jobExecutionFirestoreIdEqualTo(
        cleanedFirestoreId,
      );
      return includeDeleted ? query : query.and().isDeletedEqualTo(false);
    }

    if (jobExecutionLocalId != null) {
      final query = isar.jobDiaryEntrys.filter().jobExecutionLocalIdEqualTo(
        jobExecutionLocalId,
      );
      return includeDeleted ? query : query.and().isDeletedEqualTo(false);
    }

    final query = isar.jobDiaryEntrys.filter().firestoreIdEqualTo(
      '__no_matching_job_diary_entry__',
    );
    return includeDeleted ? query : query.and().isDeletedEqualTo(false);
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
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'job diary entry',
              firestoreId: remote.firestoreId,
            )
            : null;

    await isar.writeTxn(() async {
      final local =
          await isar.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
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
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'job diary entry',
      firestoreId: remote.firestoreId,
    );

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
