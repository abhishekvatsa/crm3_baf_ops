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
    final existing = entry.firestoreId == null
        ? null
        : await _entries.doc(entry.firestoreId).get();
    // A missing Firestore document is not a safe edit-to-create fallback. It
    // would silently sever the original diary identity and could duplicate a
    // note after a delayed pull or a deleted record. Creation has no identity;
    // an identified entry must still be present.
    final isCreate = entry.firestoreId == null;
    if (!isCreate &&
        (existing == null || !existing.exists || existing.data() == null)) {
      throw StateError(
        'The identified planned-maintenance diary entry is no longer present. Refresh before editing.',
      );
    }
    if (isCreate) {
      if (!actor.canCreateJobDiaryEntry) {
        throw StateError('Not authorized to create planned-job diary entries.');
      }
    } else if (!actor.canEditJobDiaryEntry(createdByUid: entry.createdByUid)) {
      throw StateError('Not authorized to edit this planned-job diary entry.');
    }
    final openedAtVersion = entry.version;
    _normalizeDiaryEntryForUserSave(
      entry,
      markUnsynced: false,
      preserveCreatedAt: true,
      bumpVersion: false,
    );

    entry.updatedByUid = actor.uid;
    entry.updatedByName = actor.name;
    if (isCreate) {
      if (entry.createdByUid != actor.uid) {
        throw StateError('The diary author must match the current account.');
      }
      entry.retainReviewedServerVersion(0);
    } else {
      entry.retainReviewedServerVersion(openedAtVersion);
      entry.version = openedAtVersion + 1;
    }
    await batchUpsertEntries([entry]);
    entry.isSynced = true;
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
      (snap) => snap.docs
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
      final after = afterDoc.data() != null
          ? JobDiaryEntry.fromMap(afterDoc.data()!, afterDoc.id)
          : null;

      final auditRepo = _auditRepo;
      await auditRepo.log(
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
  Future<RemoteRecordApplyResult<JobDiaryEntry>> applyEntryFromRemote(
    JobDiaryEntry remote,
  ) {
    throw UnsupportedError(
      'Firestore cannot apply a remote job diary entry to itself.',
    );
  }

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

    final snap = await query
        .limit(limit)
        .get(authoritativeGlobalPullReadOptions);
    return PaginatedDiaryResult(
      records: snap.docs
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
      final snap = await _entries
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(
        snap.docs.map((doc) => JobDiaryEntry.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertEntries(List<JobDiaryEntry> records) async {
    // Each diary intent and its exact accepted before/after evidence share a
    // transaction. Local edit count cannot substitute for the reviewed basis.
    for (final record in records) {
      final id = _cleanOptionalText(record.firestoreId);
      if (id == null) throw StateError('Diary identity is missing.');
      final reference = _entries.doc(id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        final before = data == null ? null : JobDiaryEntry.fromMap(data, id);
        final afterMap = record.toMap();
        if (before != null &&
            persistedJsonEquivalent(
              jsonEncode(before.toMap()),
              jsonEncode(afterMap),
            )) {
          return;
        }
        final basis = record.reviewedServerVersion;
        if (basis == null ||
            (before == null ? basis != 0 : basis != before.version) ||
            before?.isDeleted == true) {
          throw StateError(
            'Diary server evidence changed or its original basis is unavailable. The saved note is retained for review.',
          );
        }
        final beforeJson = before == null
            ? null
            : jsonEncode(before.toAuditMap());
        final afterJson = jsonEncode(record.toAuditMap());
        if ((beforeJson?.length ?? 0) > 20000 || afterJson.length > 20000) {
          throw StateError(
            'Diary evidence is too large for one audited amendment.',
          );
        }
        transaction.set(
          FirebaseFirestore.instance
              .collection('audit_logs')
              .doc('diary_revision_${id}_${record.version}'),
          {
            'entityType': 'planned_job_diary_entry',
            'entityId': id,
            'action': before == null ? 'create' : 'update',
            'performedByUid': record.updatedByUid,
            'performedByName': record.updatedByName,
            'timestamp': FieldValue.serverTimestamp(),
            'severity': 'low',
            'summary': 'Accepted diary revision ${record.version}',
            'reasonNotes': record.syncReviewMetadata['diaryAmendmentReason'],
            'beforeJson': beforeJson,
            'afterJson': afterJson,
            'beforeState': data,
            'afterState': {...?data, ...afterMap},
          },
        );
        transaction.set(reference, afterMap, SetOptions(merge: true));
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
