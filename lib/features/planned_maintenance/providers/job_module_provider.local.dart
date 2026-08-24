part of 'job_module_provider.dart';

class IsarJobModuleRepository implements JobModuleRepository {
  final AuditRepository _auditRepo;

  IsarJobModuleRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  @override
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
  }) async {
    final isCreate = module.id == Isar.autoIncrement;
    if (actor == null) {
      throw StateError('Actor is required when saving planned-job modules.');
    }
    if (isCreate) {
      _requireCanAddModuleDuringExecution(actor);
      _requireRuntimeModuleAddControl(actor, module);
    } else {
      _requireCanSaveModuleWork(actor, module);
    }

    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      JobModuleInstance? existing;
      if (!isCreate && module.id != Isar.autoIncrement) {
        existing = await isar.jobModuleInstances.get(module.id);
        beforeSnapshot = existing?.toAuditMap();
      }

      _normaliseModuleForUserSave(
        module,
        markUnsynced: true,
        auditContext: auditContext,
        incrementVersion: existing != null,
      );

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null && afterSnapshot != null && entityId != null) {
      final action =
          beforeSnapshot == null ? AuditAction.create : AuditAction.update;
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: action,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ??
                  (action == AuditAction.create
                      ? 'Added planned-maintenance module'
                      : 'Updated planned-maintenance module'),
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
    bool includeDeleted = false,
  }) async {
    final resolution = await _loadResolvedModulesForJob(
      jobExecutionFirestoreId: jobExecutionFirestoreId,
      jobExecutionLocalId: jobExecutionLocalId,
      discipline: discipline,
      includeDeleted: includeDeleted,
    );

    _reportForeignParentCollisions(
      resolution.ignoredForeignParentCollisions,
      jobExecutionFirestoreId,
    );
    _assertNoIdentityAmbiguity(resolution, jobExecutionFirestoreId);
    final modules = resolution.modules;
    _sortModules(modules);
    if (limit != null && modules.length > limit) {
      return modules.take(limit).toList();
    }
    return modules;
  }

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
    bool includeDeleted = false,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);

    if (cleanedFirestoreId == null) {
      return _localJobQuery(
        jobExecutionLocalId: jobExecutionLocalId,
        discipline: discipline,
        includeDeleted: includeDeleted,
      ).watch(fireImmediately: true).map((localModules) {
        final resolution = PlannedJobModuleSetResolver.resolve(
          executionFirestoreId: null,
          executionLocalId: jobExecutionLocalId ?? -1,
          firestoreLinkedModules: const <JobModuleInstance>[],
          localLinkedModules: localModules,
          includeDeleted: includeDeleted,
        );
        _reportForeignParentCollisions(
          resolution.ignoredForeignParentCollisions,
          null,
        );
        _assertNoIdentityAmbiguity(resolution, null);
        final modules = resolution.modules;
        _sortModules(modules);
        return limit != null && modules.length > limit
            ? modules.take(limit).toList()
            : modules;
      });
    }

    final remoteStream = _remoteJobQuery(
      jobExecutionFirestoreId: cleanedFirestoreId,
      discipline: discipline,
      includeDeleted: includeDeleted,
    ).watch(fireImmediately: true);
    final localStream = _localJobQuery(
      jobExecutionLocalId: jobExecutionLocalId,
      discipline: discipline,
      includeDeleted: includeDeleted,
    ).watch(fireImmediately: true);

    return _combineResolvedModuleStreams(
      remoteStream: remoteStream,
      localStream: localStream,
      jobExecutionFirestoreId: cleanedFirestoreId,
      jobExecutionLocalId: jobExecutionLocalId,
      limit: limit,
      includeDeleted: includeDeleted,
    );
  }

  Future<PlannedJobModuleSetResolution> _loadResolvedModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    bool includeDeleted = false,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    final localId = jobExecutionLocalId ?? -1;

    if (cleanedFirestoreId == null) {
      final localModules =
          jobExecutionLocalId == null
              ? <JobModuleInstance>[]
              : await _localJobQuery(
                jobExecutionLocalId: jobExecutionLocalId,
                discipline: discipline,
                includeDeleted: includeDeleted,
              ).findAll();
      return PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: null,
        executionLocalId: localId,
        firestoreLinkedModules: const <JobModuleInstance>[],
        localLinkedModules: localModules,
        includeDeleted: includeDeleted,
      );
    }

    final remoteModules =
        await _remoteJobQuery(
          jobExecutionFirestoreId: cleanedFirestoreId,
          discipline: discipline,
          includeDeleted: includeDeleted,
        ).findAll();
    final localModules =
        jobExecutionLocalId == null
            ? <JobModuleInstance>[]
            : await _localJobQuery(
              jobExecutionLocalId: jobExecutionLocalId,
              discipline: discipline,
              includeDeleted: includeDeleted,
            ).findAll();

    return PlannedJobModuleSetResolver.resolve(
      executionFirestoreId: cleanedFirestoreId,
      executionLocalId: localId,
      firestoreLinkedModules: remoteModules,
      localLinkedModules: localModules,
      includeDeleted: includeDeleted,
    );
  }

  Stream<List<JobModuleInstance>> _combineResolvedModuleStreams({
    required Stream<List<JobModuleInstance>> remoteStream,
    required Stream<List<JobModuleInstance>> localStream,
    required String jobExecutionFirestoreId,
    required int? jobExecutionLocalId,
    int? limit,
    bool includeDeleted = false,
  }) {
    late StreamController<List<JobModuleInstance>> controller;
    StreamSubscription<List<JobModuleInstance>>? remoteSubscription;
    StreamSubscription<List<JobModuleInstance>>? localSubscription;
    List<JobModuleInstance>? remoteLatest;
    List<JobModuleInstance>? localLatest;

    void emitIfReady() {
      final remote = remoteLatest;
      final local = localLatest;
      if (remote == null || local == null || controller.isClosed) return;

      final resolution = PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: jobExecutionFirestoreId,
        executionLocalId: jobExecutionLocalId ?? -1,
        firestoreLinkedModules: remote,
        localLinkedModules: local,
        includeDeleted: includeDeleted,
      );
      _reportForeignParentCollisions(
        resolution.ignoredForeignParentCollisions,
        jobExecutionFirestoreId,
      );
      try {
        _assertNoIdentityAmbiguity(resolution, jobExecutionFirestoreId);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
        return;
      }
      final modules = resolution.modules;
      _sortModules(modules);
      controller.add(
        limit != null && modules.length > limit
            ? modules.take(limit).toList()
            : modules,
      );
    }

    controller = StreamController<List<JobModuleInstance>>(
      onListen: () {
        remoteSubscription = remoteStream.listen((value) {
          remoteLatest = value;
          emitIfReady();
        }, onError: controller.addError);
        localSubscription = localStream.listen((value) {
          localLatest = value;
          emitIfReady();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await remoteSubscription?.cancel();
        await localSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
  _remoteJobQuery({
    required String jobExecutionFirestoreId,
    JobModuleDiscipline? discipline,
    bool includeDeleted = false,
  }) {
    var query = isar.jobModuleInstances.filter().jobExecutionFirestoreIdEqualTo(
      jobExecutionFirestoreId,
    );
    if (!includeDeleted) {
      query = query.and().isDeletedEqualTo(false);
    }
    if (discipline != null) {
      query = query.and().disciplineEqualTo(discipline);
    }
    return query;
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
  _localJobQuery({
    required int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    bool includeDeleted = false,
  }) {
    var query =
        jobExecutionLocalId == null
            ? isar.jobModuleInstances.filter().firestoreIdEqualTo(
              '__no_matching_job_module__',
            )
            : isar.jobModuleInstances.filter().jobExecutionLocalIdEqualTo(
              jobExecutionLocalId,
            );
    if (!includeDeleted) {
      query = query.and().isDeletedEqualTo(false);
    }
    if (discipline != null) {
      query = query.and().disciplineEqualTo(discipline);
    }
    return query;
  }

  void _reportForeignParentCollisions(
    Iterable<JobModuleInstance> collisions,
    String? currentExecutionFirestoreId,
  ) {
    for (final module in collisions) {
      debugPrint(
        '⚠️ Ignored foreign-parent module linked by a non-authoritative local id: '
        'module=${module.moduleTitle}, moduleFirestoreId=${module.firestoreId}, '
        'actualExecution=${module.jobExecutionFirestoreId}, '
        'currentExecution=$currentExecutionFirestoreId, '
        'localExecutionId=${module.jobExecutionLocalId}',
      );
    }
  }

  void _assertNoIdentityAmbiguity(
    PlannedJobModuleSetResolution resolution,
    String? currentExecutionFirestoreId,
  ) {
    final unresolved = resolution.unresolvedLocalParentModules;
    if (unresolved.isNotEmpty) {
      final ids = unresolved
          .map((module) => module.firestoreId ?? 'local:${module.id}')
          .join(', ');
      throw StateError(
        'Planned-job module identity is unresolved for '
        '${unresolved.length} local module(s). The current execution has '
        'canonical Firestore id $currentExecutionFirestoreId, but these '
        'modules do not. Sync/reconciliation must repair the parent relation '
        'before work or closure can continue. Modules: $ids',
      );
    }

    final duplicates = resolution.duplicateCanonicalModules;
    if (duplicates.isNotEmpty) {
      final ids = duplicates
          .map(
            (module) =>
                '${module.firestoreId ?? 'local:${module.id}'}@isar:${module.id}',
          )
          .join(', ');
      throw StateError(
        'Planned-job module identity is ambiguous: distinct local rows claim '
        'the same canonical module Firestore id. Resolve the duplicate without '
        'discarding evidence before work or closure can continue. Rows: $ids',
      );
    }
  }

  static void _sortModules(List<JobModuleInstance> modules) {
    modules.sort((a, b) {
      final displayOrderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (displayOrderCompare != 0) return displayOrderCompare;

      final disciplineCompare = a.discipline.name.compareTo(b.discipline.name);
      if (disciplineCompare != 0) return disciplineCompare;

      return a.moduleTitle.compareTo(b.moduleTitle);
    });
  }

  @override
  Future<void> softDeleteModule(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final moduleId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final module = await isar.jobModuleInstances.get(moduleId);
      if (module == null || module.isDeleted) return;
      _requireCanModerateModule(actor, ModuleModerationAction.softDelete);

      beforeSnapshot = module.toAuditMap();
      final now = DateTime.now();

      module
        ..isDeleted = true
        ..deletedAt = now
        ..deletedByUid = actor.uid
        ..deletedByName = _cleanOptionalText(actor.name)
        ..deleteReason = auditContext?.reason?.name ?? auditContext?.reasonNotes
        ..updatedAt = now
        ..updatedByUid =
            _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
        ..updatedByName =
            _cleanOptionalText(auditContext?.performedByName) ??
            _cleanOptionalText(actor.name)
        ..version += 1
        ..isSynced = false;

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ?? 'Deleted planned-maintenance module',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  }) async {
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.update,
      auditSummary: 'Submitted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanSubmitModule(actor, module);
        _requireOpenForWork(module, 'submit this module');
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.submitted
          ..submittedByUid = actor.uid
          ..submittedByName = _cleanOptionalText(actor.name)
          ..submittedAt = now
          ..submissionNote = _cleanOptionalText(submissionNote)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
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
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.reopen,
      auditSummary: 'Reopened planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.reopen);
        _requireReopenable(module);
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.reopened
          ..reopenedByUid = actor.uid
          ..reopenedByName = _cleanOptionalText(actor.name)
          ..reopenedAt = now
          ..reopenReason = _cleanOptionalText(reopenReason)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
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
    final module =
        await isar.jobModuleInstances
            .filter()
            .firestoreIdEqualTo(firestoreId)
            .findFirst();
    if (module == null) return;
    await isar.writeTxn(() async {
      module
        ..status = JobModuleStatus.reopened
        ..isDeleted = false
        ..reopenedByUid = actor.uid
        ..reopenedByName = _cleanOptionalText(actor.name)
        ..reopenedAt = appliedAt
        ..reopenReason = _cleanOptionalText(reason)
        ..updatedByUid = actor.uid
        ..updatedByName = _cleanOptionalText(actor.name)
        ..updatedAt = appliedAt
        ..version += 1
        ..isSynced = true;
      await isar.jobModuleInstances.put(module);
    });
  }

  @override
  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  }) async {
    await _transitionLocalModule(
      id as int,
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
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.notApplicable
          ..notApplicableByUid = actor.uid
          ..notApplicableByName = _cleanOptionalText(actor.name)
          ..notApplicableAt = now
          ..notApplicableReason = _cleanRequiredText(reason, 'Not applicable')
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
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
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.update,
      auditSummary: 'Accepted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.accept);
        _requireSubmitted(module, 'accept this module');
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.accepted
          ..acceptedByUid = actor.uid
          ..acceptedByName = _cleanOptionalText(actor.name)
          ..acceptedAt = now
          ..acceptanceNote = _cleanOptionalText(acceptanceNote)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
      },
    );
  }

  Future<void> _transitionLocalModule(
    int id, {
    required AuditAction auditAction,
    required String auditSummary,
    required void Function(JobModuleInstance module, DateTime now) mutate,
    void Function(JobModuleInstance module)? validate,
    AuditContext? auditContext,
  }) async {
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final module = await isar.jobModuleInstances.get(id);
      if (module == null || module.isDeleted) return;

      validate?.call(module);
      beforeSnapshot = module.toAuditMap();
      final now = DateTime.now();
      mutate(module, now);
      module
        ..updatedAt = now
        ..version += 1
        ..isSynced = false;

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: auditAction,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary: auditContext.summary ?? auditSummary,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<JobModuleInstance?> getModuleByFirestoreId(String firestoreId) async {
    return isar.jobModuleInstances
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async {
    return isar.jobModuleInstances.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markModulesSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    await isar.writeTxn(() async {
      final modules = await isar.jobModuleInstances.getAll(ids);
      for (final module in modules.whereType<JobModuleInstance>()) {
        module.isSynced = true;
        await isar.jobModuleInstances.put(module);
      }
    });
  }

  @override
  Future<void> markModulesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final modules = await isar.jobModuleInstances.getAll(byId.keys.toList());
      for (final module in modules.whereType<JobModuleInstance>()) {
        final pushed = byId[module.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: module.version,
          currentUpdatedAt: module.updatedAt,
        )) {
          continue;
        }
        module.isSynced = true;
        await isar.jobModuleInstances.put(module);
      }
    });
  }

  @override
  Future<void> insertModuleFromRemote(JobModuleInstance remote) async {
    remote
      ..jobExecutionLocalId = null
      ..isSynced = true;
    await isar.writeTxn(() => isar.jobModuleInstances.put(remote));
  }

  @override
  Future<void> updateModuleFromRemote(JobModuleInstance remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'job module',
              firestoreId: remote.firestoreId,
            )
            : null;

    await isar.writeTxn(() async {
      final local =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced module against remote tombstone in updateModuleFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          _copyRemoteModuleIntoLocal(local, remote);
          await isar.jobModuleInstances.put(local);
        }
        return;
      }

      final isLocalUnsynced = !local.isSynced;
      final isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
    });
  }

  @override
  Future<bool> applyModuleServerReadbackIfUnchanged(
    JobModuleInstance remote, {
    required SyncPushSnapshot expectedLocal,
    required bool expectedLocalSynced,
    String? reason,
  }) async {
    final firestoreId = remote.firestoreId?.trim();
    if (firestoreId == null || firestoreId.isEmpty) return false;

    final applied = await isar.writeTxn<bool>(() async {
      final local =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();

      if (local == null || local.id != expectedLocal.id) return false;
      final alreadyAtServerBoundary =
          local.isSynced &&
          local.version == remote.version &&
          local.updatedAt.isAtSameMomentAs(remote.updatedAt);
      final stillAtExpectedBoundary =
          local.isSynced == expectedLocalSynced &&
          expectedLocal.matches(
            currentVersion: local.version,
            currentUpdatedAt: local.updatedAt,
          );
      if (!alreadyAtServerBoundary && !stillAtExpectedBoundary) return false;

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
      return true;
    });

    if (applied && reason != null && reason.trim().isNotEmpty) {
      debugPrint(
        '🛡️ Rebased local job module from remote canonical state: '
        'firestoreId=${remote.firestoreId}, reason=$reason',
      );
    }
    return applied;
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobModuleInstance remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'job module',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced module against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<PaginatedJobModuleResult> getUpdatedModules({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedJobModuleResult(records: [], lastDoc: null);
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobModuleInstance>[];
    for (final firestoreId in ids) {
      final module =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();
      if (module != null) results.add(module);
    }
    return results;
  }

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    if (records.isEmpty) return;
    await isar.writeTxn(() async {
      for (final record in records) {
        if (_cleanOptionalText(record.jobExecutionFirestoreId) != null) {
          record.jobExecutionLocalId = null;
        }
        await isar.jobModuleInstances.put(record);
      }
    });
  }

  @override
  Future<void> applyRemoteLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) {
    throw UnsupportedError(
      'applyRemoteLifecycleReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar job-module repository.',
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
