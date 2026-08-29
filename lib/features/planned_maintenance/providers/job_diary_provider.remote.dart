part of 'job_diary_provider.dart';

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
    bool includeDeleted = false,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) return [];

    Future<List<JobDiaryEntry>> loadDeletedState(bool isDeleted) async {
      Query<Map<String, dynamic>> query = _entries
          .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
          .where('isDeleted', isEqualTo: isDeleted)
          .orderBy('createdAt', descending: true);

      if (limit != null) query = query.limit(limit);

      final snap = await query.get();
      return snap.docs
          .map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id))
          .toList();
    }

    if (!includeDeleted) {
      return loadDeletedState(false);
    }

    final activeRequest = loadDeletedState(false);
    final deletedRequest = loadDeletedState(true);
    final entries = <JobDiaryEntry>[
      ...await activeRequest,
      ...await deletedRequest,
    ]..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return limit == null ? entries : entries.take(limit).toList();
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
