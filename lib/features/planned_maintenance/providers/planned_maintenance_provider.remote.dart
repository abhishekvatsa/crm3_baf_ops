part of 'planned_maintenance_provider.dart';

class FirestorePlannedRepository extends PlannedMaintenanceRepository {
  final AuditRepository _auditRepo;
  final PlannedJobServerCompletionService _serverCompletion;

  FirestorePlannedRepository({
    AuditRepository? auditRepository,
    PlannedJobServerCompletionService? serverCompletion,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _serverCompletion =
           serverCompletion ?? PlannedJobServerCompletionService();

  final _templates = FirebaseFirestore.instance.collection('job_templates');
  final _executions = FirebaseFirestore.instance.collection('job_executions');

  Map<String, dynamic>? _sanitizeForAudit(Map<String, dynamic>? data) {
    if (data == null) return null;
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is FieldValue) {
        sanitized[key] = value.toString();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  @override
  Stream<List<JobTemplate>> watchAllTemplates({int? limit}) {
    var query = _templates
        .where('isDeleted', isEqualTo: false)
        .orderBy('jobName');

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobTemplate.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchAllExecutions({int? limit}) {
    var query = _executions
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchExecutionsOverlappingPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream<List<JobExecution>>.error(
        ArgumentError('Report start must precede report end.'),
      );
    }
    Stream<List<JobExecution>> decode(
      firestore.Query<Map<String, dynamic>> query,
    ) => query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
          .toList(growable: false),
    );
    final startBound = plannedExecutionReportTimestampBound(startInclusive);
    final endBound = plannedExecutionReportTimestampBound(endExclusive);

    final startedInPeriod = decode(
      _executions
          .where('isDeleted', isEqualTo: false)
          .where('createdAt', isGreaterThanOrEqualTo: startBound)
          .where('createdAt', isLessThan: endBound)
          .orderBy('createdAt', descending: true),
    );
    final openCarryIn = decode(
      _executions
          .where('isCompleted', isEqualTo: false)
          .where('isCancelled', isEqualTo: false)
          .where('isDeleted', isEqualTo: false)
          .where('createdAt', isLessThan: startBound)
          .orderBy('createdAt', descending: true),
    );
    final completedAcrossStart = decode(
      _executions
          .where('isCompleted', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .where('completedAt', isGreaterThan: startBound)
          .orderBy('completedAt', descending: true),
    );
    final cancelledAcrossStart = decode(
      _executions
          .where('isCancelled', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .where('cancelledAt', isGreaterThan: startBound)
          .orderBy('cancelledAt', descending: true),
    );

    return combineLatestUniqueRecordStreams<JobExecution>(
      streams: [
        startedInPeriod,
        openCarryIn,
        completedAcrossStart,
        cancelledAcrossStart,
      ],
      identityOf: (record) => record.firestoreId ?? 'local:${record.id}',
      compare: (left, right) => right.createdAt.compareTo(left.createdAt),
    ).map(
      (records) => records
          .where(
            (record) => jobExecutionOverlapsPeriod(
              record,
              startInclusive,
              endExclusive,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<JobExecution>> watchOpenExecutions() {
    return _executions
        .where('isCompleted', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
                  .where((execution) => !execution.isCancelled)
                  .toList(),
        );
  }

  @override
  Stream<List<JobExecution>> watchExecutionsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _executions
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchExecutionsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _executions
        .where('assetType', isEqualTo: type.name)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> completeExecution(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
  }) async {
    if (!actor.canCompleteJobExecution) {
      throw StateError('You are not authorized to complete planned jobs.');
    }

    final docId = id as String;

    // M6 full enforcement: direct client writes to job_executions completion
    // are denied by Firestore rules. The callable function re-loads modules,
    // applies the closure guard server-side, writes the completion with Admin
    // SDK, and emits the canonical audit event.
    await _serverCompletion.completeExecution(
      executionFirestoreId: docId,
      remarks: remarks,
      teamsInvolved: teamsInvolved,
      responses: responses,
      actions: actions,
    );
  }

  @override
  Future<List<JobExecution>> getExecutionsForTemplate(
    String templateFirestoreId,
  ) async {
    final snap =
        await _executions
            .where('templateFirestoreId', isEqualTo: templateFirestoreId)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> saveTemplate(
    JobTemplate template, {
    required AppUser actor,
  }) async {
    _requireCanSaveLegacyTemplate(actor);
    if (template.firestoreId == null) throw Exception('firestoreId required');
    _normalizeTemplateForUserSave(template, markUnsynced: false);
    await _templates
        .doc(template.firestoreId)
        .set(template.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<JobTemplate>> getAllTemplates() async {
    final snap = await _templates.where('isDeleted', isEqualTo: false).get();
    return snap.docs
        .map((doc) => JobTemplate.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<JobTemplate?> getTemplateById(dynamic id) async {
    final doc = await _templates.doc(id as String).get();
    if (!doc.exists) return null;
    return JobTemplate.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> deleteTemplate(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanDeleteLegacyTemplate(actor);
    final docId = id as String;

    final beforeDoc = await _templates.doc(docId).get();
    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'updatedAt': now,
      'version': nextVersion,
    };
    if (auditContext != null) {
      updateData['deletedByUid'] = auditContext.performedByUid;
      updateData['deletedByName'] = auditContext.performedByName;
      updateData['deleteReason'] =
          auditContext.reason?.name ?? auditContext.reasonNotes;
    }
    await _templates.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'template',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTemplateRemote(
    JobTemplate remote,
  ) async {
    // No-op on web. Firestore is the source of truth and is observed via
    // .snapshots() — there is no separate "local store" to tombstone.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> saveExecution(
    JobExecution execution, {
    required AppUser actor,
  }) async {
    _requireCanAssignJobExecution(actor);
    if (execution.firestoreId == null) throw Exception('firestoreId required');
    _normalizeExecutionForUserSave(execution, markUnsynced: false);
    await _executions
        .doc(execution.firestoreId)
        .set(execution.toClientWritableMap(), SetOptions(merge: true));
  }

  @override
  Future<List<JobExecution>> getAllExecutions() async {
    final snap = await _executions.where('isDeleted', isEqualTo: false).get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<JobExecution>> getOpenExecutions() async {
    final snap =
        await _executions
            .where('isCompleted', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .where((execution) => !execution.isCancelled)
        .toList();
  }

  @override
  Future<List<JobExecution>> getExecutionsForAsset(
    AssetType type,
    int number,
  ) async {
    final snap =
        await _executions
            .where('assetType', isEqualTo: type.name)
            .where('assetNumber', isEqualTo: number)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> deleteExecution(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    if (!actor.canDeleteJobExecution) {
      throw StateError('Not authorized to delete planned job executions.');
    }
    final docId = id as String;

    final beforeDoc = await _executions.doc(docId).get();
    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'updatedAt': now,
      'version': nextVersion,
    };
    if (auditContext != null) {
      updateData['deletedByUid'] = auditContext.performedByUid;
      updateData['deletedByName'] = auditContext.performedByName;
      updateData['deleteReason'] =
          auditContext.reason?.name ?? auditContext.reasonNotes;
    }
    await _executions.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'execution',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromExecutionRemote(
    JobExecution remote,
  ) async {
    // No-op on web. See applyTombstoneFromTemplateRemote.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async => [];

  @override
  Future<void> markTemplatesSynced(List<int> ids) async {}

  @override
  Future<void> markTemplatesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId) async {
    final doc = await _templates.doc(firestoreId).get();
    if (!doc.exists) return null;
    return JobTemplate.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> insertTemplateFromRemote(JobTemplate remote) async {}

  @override
  Future<void> updateTemplateFromRemote(JobTemplate remote) async {}

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async => [];

  @override
  Future<void> markExecutionsSynced(List<int> ids) async {}

  @override
  Future<void> markExecutionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<JobExecution?> getExecutionByFirestoreId(String firestoreId) async {
    final doc = await _executions.doc(firestoreId).get();
    if (!doc.exists) return null;
    return JobExecution.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> insertExecutionFromRemote(JobExecution remote) async {}

  @override
  Future<void> updateExecutionFromRemote(JobExecution remote) async {}

  @override
  Future<void> forceRebaseExecutionFromRemote(
    JobExecution remote, {
    String? reason,
  }) async {}

  @override
  Future<PaginatedTemplateResult> getUpdatedTemplates({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-template pull has no server upper bound.',
        reasonCode: 'job-template-server-anchor-missing',
      );
    }
    var q = globalPullServerWindowQuery(
      _templates,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.limit(limit).get();
    return PaginatedTemplateResult(
      records:
          snap.docs.map((d) => JobTemplate.fromMap(d.data(), d.id)).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedExecutionResult> getUpdatedExecutions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-execution pull has no server upper bound.',
        reasonCode: 'job-execution-server-anchor-missing',
      );
    }
    var q = globalPullServerWindowQuery(
      _executions,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.limit(limit).get();
    return PaginatedExecutionResult(
      records:
          snap.docs.map((d) => JobExecution.fromMap(d.data(), d.id)).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<JobTemplate>> getTemplatesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <JobTemplate>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _templates.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobTemplate.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertTemplates(List<JobTemplate> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      if (r.firestoreId != null) {
        batch.set(
          _templates.doc(r.firestoreId),
          r.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<List<JobExecution>> getExecutionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobExecution>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _executions.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobExecution.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertExecutions(List<JobExecution> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      if (r.firestoreId != null) {
        batch.set(
          _executions.doc(r.firestoreId),
          r.toClientWritableMap(),
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
