part of 'job_module_provider.dart';

class _RemoteModuleTransitionResult {
  final JobModuleInstance before;

  const _RemoteModuleTransitionResult({required this.before});
}

class FirestoreJobModuleRepository implements JobModuleRepository {
  final AuditRepository _auditRepo;
  final RuntimeJobModulePopulationService _populationService;

  FirestoreJobModuleRepository({
    AuditRepository? auditRepository,
    RuntimeJobModulePopulationService? populationService,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _populationService =
           populationService ?? RuntimeJobModulePopulationService();

  final _modules = FirebaseFirestore.instance.collection('job_modules');

  @override
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
  }) async {
    final existing =
        module.firestoreId == null
            ? null
            : await _modules.doc(module.firestoreId).get();
    final before =
        existing != null && existing.exists && existing.data() != null
            ? JobModuleInstance.fromMap(existing.data()!, existing.id)
            : null;

    if (actor == null) {
      throw StateError('Actor is required when saving planned-job modules.');
    }
    if (before == null) {
      _requireCanAddModuleDuringExecution(actor);
      _requireRuntimeModuleAddControl(actor, module);
    } else {
      _requireCanSaveModuleWork(actor, module);
    }

    _normaliseModuleForUserSave(
      module,
      markUnsynced: false,
      auditContext: auditContext,
      preserveCreatedAt: true,
      incrementVersion: before != null,
    );

    if (before == null) {
      final accepted = await _populationService.acceptModule(module);
      _copyRemoteModuleIntoLocal(module, accepted.module);
    } else {
      await _modules
          .doc(module.firestoreId)
          .set(module.toMap(), SetOptions(merge: true));
    }
    module.isSynced = true;

    if (auditContext != null && before != null) {
      // First remote acceptance already writes the authoritative immutable
      // create audit in the same server transaction as the child and parent
      // population-fence update. Emit a client audit only for later ordinary
      // lifecycle/work updates, never a duplicate create record.
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: module.firestoreId!,
            action: AuditAction.update,
            context: auditContext.copyWith(
              before: before.toAuditMap(),
              after: module.toAuditMap(),
              summary:
                  auditContext.summary ?? 'Updated planned-maintenance module',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) return [];

    Query<Map<String, dynamic>> query = _modules
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('displayOrder')
        .orderBy('moduleTitle');

    if (discipline != null) {
      query = query.where('discipline', isEqualTo: discipline.name);
    }

    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
    return snap.docs
        .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) {
      return Stream<List<JobModuleInstance>>.value(const []);
    }

    Query<Map<String, dynamic>> query = _modules
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('displayOrder')
        .orderBy('moduleTitle');

    if (discipline != null) {
      query = query.where('discipline', isEqualTo: discipline.name);
    }

    if (limit != null) query = query.limit(limit);

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> softDeleteModule(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final docId = id as String;
    _requireCanModerateModule(actor, ModuleModerationAction.softDelete);

    final doc = await _modules.doc(docId).get();
    if (!doc.exists || doc.data() == null) return;
    final before = JobModuleInstance.fromMap(doc.data()!, doc.id);
    if (before.isDeleted) return;

    final now = DateTime.now();
    final tombstone =
        JobModuleInstance.fromMap(before.toMap(), doc.id)
          ..isDeleted = true
          ..deletedAt = now
          ..deletedByUid = actor.uid
          ..deletedByName = _cleanOptionalText(actor.name)
          ..deleteReason =
              auditContext?.reason?.name ?? auditContext?.reasonNotes
          ..updatedAt = now
          ..updatedByUid = actor.uid
          ..updatedByName = _cleanOptionalText(actor.name)
          ..version = before.version + 1;

    final after = await _populationService.softDeleteModule(tombstone);
    _copyRemoteModuleIntoLocal(tombstone, after.module);

    // The server callable writes the only authoritative delete audit in the
    // same transaction as the tombstone and parent population increment.
    // Do not create a second client-side audit for the same mutation.
  }

  @override
  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Submitted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanSubmitModule(actor, module);
        _requireOpenForWork(module, 'submit this module');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.submitted.name,
            'isOpenForWork': false,
            'submittedByUid': actor.uid,
            'submittedByName': _cleanOptionalText(actor.name),
            'submittedAt': now.toIso8601String(),
            'submissionNote': _cleanOptionalText(submissionNote),
          },
    );
  }

  @override
  Future<void> reopenModule(
    dynamic id, {
    required AppUser actor,
    String? reopenReason,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.reopen,
      auditSummary: 'Reopened planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.reopen);
        _requireReopenable(module);
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.reopened.name,
            'isOpenForWork': true,
            'reopenedByUid': actor.uid,
            'reopenedByName': _cleanOptionalText(actor.name),
            'reopenedAt': now.toIso8601String(),
            'reopenReason': _cleanOptionalText(reopenReason),
          },
    );
  }

  @override
  Future<void> applyWorkflowModuleReopenProjection(
    String firestoreId, {
    required AppUser actor,
    required String reason,
    required DateTime appliedAt,
  }) async {
    // The workflow command has already committed the canonical Firestore
    // transition. Web views observe that document directly.
  }

  @override
  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Marked planned-maintenance module not applicable',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(
          actor,
          ModuleModerationAction.markNotApplicable,
        );
        _requireOpenForWork(module, 'mark this module not applicable');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.notApplicable.name,
            'isOpenForWork': false,
            'notApplicableByUid': actor.uid,
            'notApplicableByName': _cleanOptionalText(actor.name),
            'notApplicableAt': now.toIso8601String(),
            'notApplicableReason': _cleanRequiredText(reason, 'Not applicable'),
          },
    );
  }

  @override
  Future<void> acceptModule(
    dynamic id, {
    required AppUser actor,
    String? acceptanceNote,
    AuditContext? auditContext,
  }) async {
    // Accept is a per-module review decision. It does not complete the parent
    // JobExecution and it does not evaluate required-for-closure job gating.
    // Accepted modules are locked for normal users and may only be reopened by
    // supervisor/Admin/SI with a reason.
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Accepted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.accept);
        _requireSubmitted(module, 'accept this module');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.accepted.name,
            'isOpenForWork': false,
            'acceptedByUid': actor.uid,
            'acceptedByName': _cleanOptionalText(actor.name),
            'acceptedAt': now.toIso8601String(),
            'acceptanceNote': _cleanOptionalText(acceptanceNote),
          },
    );
  }

  Future<void> _transitionRemoteModule(
    String docId, {
    required AuditAction auditAction,
    required String auditSummary,
    required Map<String, dynamic> Function(DateTime now) buildUpdate,
    void Function(JobModuleInstance module)? validate,
    AuditContext? auditContext,
  }) async {
    final docRef = _modules.doc(docId);

    final result = await FirebaseFirestore.instance
        .runTransaction<_RemoteModuleTransitionResult?>((transaction) async {
          final doc = await transaction.get(docRef);
          if (!doc.exists || doc.data() == null) return null;

          final before = JobModuleInstance.fromMap(doc.data()!, doc.id);
          validate?.call(before);

          final now = DateTime.now();
          final updateMap = <String, dynamic>{
            ...buildUpdate(now),
            'updatedAt': now.toIso8601String(),
            'version': FieldValue.increment(1),
          };

          if (auditContext != null) {
            updateMap['updatedByUid'] = auditContext.performedByUid;
            updateMap['updatedByName'] = auditContext.performedByName;
          }

          transaction.update(docRef, updateMap);

          return _RemoteModuleTransitionResult(before: before);
        });

    if (result == null || auditContext == null) return;

    final afterDoc = await docRef.get();
    final after =
        afterDoc.data() != null
            ? JobModuleInstance.fromMap(afterDoc.data()!, afterDoc.id)
            : null;

    final auditRepo = _auditRepo;
    try {
      await auditRepo.log(
        AuditEvent.fromContext(
          entityType: 'planned_job_module',
          entityId: docId,
          action: auditAction,
          context: auditContext.copyWith(
            before: result.before.toAuditMap(),
            after: after?.toAuditMap(),
            summary: auditContext.summary ?? auditSummary,
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        '⚠️ Remote planned-job module transition audit failed for $docId: $error',
      );
    }
  }

  @override
  Future<JobModuleInstance?> getModuleByFirestoreId(String firestoreId) async {
    final doc = await _modules.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;
    return JobModuleInstance.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async => [];

  @override
  Future<void> markModulesSynced(List<int> ids) async {}

  @override
  Future<void> markModulesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertModuleFromRemote(JobModuleInstance remote) async {}

  @override
  Future<void> updateModuleFromRemote(JobModuleInstance remote) async {}

  @override
  Future<void> forceRebaseModuleFromRemote(
    JobModuleInstance remote, {
    String? reason,
  }) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobModuleInstance remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<PaginatedJobModuleResult> getUpdatedModules({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-module pull has no server upper bound.',
        reasonCode: 'job-module-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _modules,
      afterInclusive: since,
      throughInclusive: through,
    );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.limit(limit).get();
    return PaginatedJobModuleResult(
      records:
          snap.docs
              .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final results = <JobModuleInstance>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _modules.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    if (records.isEmpty) return;

    final recordsWithIds = records
        .where((record) => _cleanOptionalText(record.firestoreId) != null)
        .toList(growable: false);
    if (recordsWithIds.isEmpty) return;

    final remote = await getModulesByFirestoreIds(
      recordsWithIds.map((record) => record.firestoreId!).toList(),
    );
    final remoteById = <String, JobModuleInstance>{
      for (final record in remote)
        if (record.firestoreId != null) record.firestoreId!: record,
    };

    final directUpdates = <JobModuleInstance>[];
    for (final record in recordsWithIds) {
      final firestoreId = record.firestoreId!;
      final existing = remoteById[firestoreId];

      if (record.isDeleted) {
        // Deleting a never-synchronized local module is already remotely
        // satisfied: there is no child document to remove from the population.
        if (existing == null || existing.isDeleted) continue;
        await _populationService.softDeleteModule(record);
        continue;
      }

      if (existing == null) {
        await _populationService.acceptModule(record);
        continue;
      }

      // A first acceptance may have committed even when the client lost the
      // callable response. If the canonical client payload already matches,
      // remote acceptance is satisfied and the sync layer may safely mark the
      // unchanged local snapshot synchronized without issuing a stale
      // same-version direct update.
      if (jobModuleClientSnapshotsEquivalentForSync(record, existing)) {
        continue;
      }

      directUpdates.add(record);
    }

    final firestore = FirebaseFirestore.instance;
    for (var i = 0; i < directUpdates.length; i += 500) {
      final chunk = directUpdates.sublist(
        i,
        i + 500 > directUpdates.length ? directUpdates.length : i + 500,
      );
      final batch = firestore.batch();
      for (final record in chunk) {
        batch.set(
          _modules.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  @override
  Future<void> applyRemoteLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteLifecycleReplayStepForSync requires a non-empty firestoreId',
      );
    }

    // Field-scoped merge: the caller provides only the keys for one lifecycle
    // rule branch. This avoids pushing a final dirty snapshot that collapses
    // submit+accept into a single Firestore update.
    await _modules.doc(id).set(stepData, SetOptions(merge: true));
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
