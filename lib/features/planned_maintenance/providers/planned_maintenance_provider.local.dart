part of 'planned_maintenance_provider.dart';

class IsarPlannedRepository extends PlannedMaintenanceRepository {
  final AuditRepository _auditRepo;
  final PlannedJobServerCompletionService _serverCompletion;

  IsarPlannedRepository({
    AuditRepository? auditRepository,
    PlannedJobServerCompletionService? serverCompletion,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _serverCompletion =
           serverCompletion ?? PlannedJobServerCompletionService();

  @override
  Future<void> saveTemplate(
    JobTemplate template, {
    required AppUser actor,
  }) async {
    _requireCanSaveLegacyTemplate(actor);
    _normalizeTemplateForUserSave(template, markUnsynced: true);
    await isar.writeTxn(() => isar.jobTemplates.put(template));
  }

  @override
  Future<List<JobTemplate>> getAllTemplates() async {
    return await isar.jobTemplates.filter().isDeletedEqualTo(false).findAll();
  }

  @override
  Stream<List<JobTemplate>> watchAllTemplates({int? limit}) {
    if (limit != null) {
      return isar.jobTemplates
          .filter()
          .isDeletedEqualTo(false)
          .sortByJobName()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobTemplates
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((templates) {
          templates.sort((a, b) => a.jobName.compareTo(b.jobName));
          return templates;
        });
  }

  @override
  Future<JobTemplate?> getTemplateById(dynamic id) async {
    return await isar.jobTemplates.get(id as int);
  }

  @override
  Future<void> deleteTemplate(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanDeleteLegacyTemplate(actor);
    final templateId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final t = await isar.jobTemplates.get(templateId);
      if (t != null && !t.isDeleted) {
        beforeSnapshot = t.toAuditMap();

        t.isDeleted = true;
        if (auditContext != null) {
          // User-initiated delete: full bookkeeping + version bump so
          // updateTemplateFromRemote reconciliation correctly identifies the
          // delete as the winner against concurrent peer edits.
          t.deletedAt = DateTime.now();
          t.deletedByUid = auditContext.performedByUid;
          t.deletedByName = auditContext.performedByName;
          t.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          t.updatedAt = DateTime.now();
          t.version += 1;
        } else {
          // Legacy pull-replay path (until global_pull_service is switched
          // to applyTombstoneFromTemplateRemote). Minimal write only — the
          // remote tombstone metadata is applied separately by
          // updateTemplateFromRemote when this branch is taken.
          t.updatedAt = DateTime.now();
        }
        t.isSynced = false;
        await isar.jobTemplates.put(t);

        afterSnapshot = t.toAuditMap();
        entityIdStr = t.firestoreId ?? t.id.toString();
      }
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityIdStr != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'template',
            entityId: entityIdStr!,
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
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'job template',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobTemplates
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local template against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remoteDeleteTime
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.jobTemplates.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> saveExecution(
    JobExecution execution, {
    required AppUser actor,
  }) async {
    _requireCanAssignJobExecution(actor);
    _normalizeExecutionForUserSave(execution, markUnsynced: true);
    await isar.writeTxn(() => isar.jobExecutions.put(execution));
  }

  @override
  Future<List<JobExecution>> getAllExecutions() async {
    return await isar.jobExecutions.filter().isDeletedEqualTo(false).findAll();
  }

  @override
  Future<List<JobExecution>> getOpenExecutions() async {
    final rows =
        await isar.jobExecutions
            .filter()
            .isCompletedEqualTo(false)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    return rows.where((execution) => !execution.isCancelled).toList();
  }

  @override
  Future<List<JobExecution>> getExecutionsForAsset(
    AssetType type,
    int number,
  ) async {
    return await isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }

  @override
  Future<List<JobExecution>> getExecutionsForTemplate(
    String templateFirestoreId,
  ) async {
    return await isar.jobExecutions
        .filter()
        .templateFirestoreIdEqualTo(templateFirestoreId)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
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
    final executionId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final e = await isar.jobExecutions.get(executionId);
      if (e != null && !e.isDeleted) {
        beforeSnapshot = e.toAuditMap();

        e.isDeleted = true;
        if (auditContext != null) {
          // User-initiated delete: full bookkeeping + version bump.
          e.deletedAt = DateTime.now();
          e.deletedByUid = auditContext.performedByUid;
          e.deletedByName = auditContext.performedByName;
          e.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          e.updatedAt = DateTime.now();
          e.version += 1;
        } else {
          // Legacy pull-replay path. Minimal write only.
          e.updatedAt = DateTime.now();
        }
        e.isSynced = false;
        await isar.jobExecutions.put(e);

        afterSnapshot = e.toAuditMap();
        entityIdStr = e.firestoreId ?? e.id.toString();
      }
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityIdStr != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'execution',
            entityId: entityIdStr!,
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
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'job execution',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local execution against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remoteDeleteTime
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.jobExecutions.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Stream<List<JobExecution>> watchAllExecutions({int? limit}) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .isDeletedEqualTo(false)
          .sortByUpdatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  @override
  Stream<List<JobExecution>> watchOpenExecutions() {
    return isar.jobExecutions
        .filter()
        .isCompletedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          final active =
              list.where((execution) => !execution.isCancelled).toList();
          active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return active;
        });
  }

  @override
  Stream<List<JobExecution>> watchExecutionsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .assetNumberEqualTo(number)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Stream<List<JobExecution>> watchExecutionsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<List<JobModuleInstance>> _loadModulesForExecution(
    JobExecution execution,
  ) async {
    final executionFirestoreId = _cleanOptionalText(execution.firestoreId);
    final firestoreLinked =
        executionFirestoreId == null
            ? <JobModuleInstance>[]
            : await isar.jobModuleInstances
                .filter()
                .jobExecutionFirestoreIdEqualTo(executionFirestoreId)
                .and()
                .isDeletedEqualTo(false)
                .findAll();
    final localLinked =
        await isar.jobModuleInstances
            .filter()
            .jobExecutionLocalIdEqualTo(execution.id)
            .and()
            .isDeletedEqualTo(false)
            .findAll();

    final resolution = PlannedJobModuleSetResolver.resolve(
      executionFirestoreId: executionFirestoreId,
      executionLocalId: execution.id,
      firestoreLinkedModules: firestoreLinked,
      localLinkedModules: localLinked,
    );

    for (final collision in resolution.ignoredForeignParentCollisions) {
      debugPrint(
        '⚠️ Ignored foreign-parent module during planned-job completion: '
        'module=${collision.moduleTitle}, '
        'moduleFirestoreId=${collision.firestoreId}, '
        'actualExecution=${collision.jobExecutionFirestoreId}, '
        'currentExecution=$executionFirestoreId, '
        'localExecutionId=${collision.jobExecutionLocalId}',
      );
    }

    if (resolution.unresolvedLocalParentModules.isNotEmpty) {
      final ids = resolution.unresolvedLocalParentModules
          .map((module) => module.firestoreId ?? 'local:${module.id}')
          .join(', ');
      throw StateError(
        'Cannot complete planned job: '
        '${resolution.unresolvedLocalParentModules.length} module(s) have an '
        'unresolved local parent identity and are not visible to the canonical '
        'server execution $executionFirestoreId. Reconcile before closure. '
        'Modules: $ids',
      );
    }

    if (resolution.duplicateCanonicalModules.isNotEmpty) {
      final ids = resolution.duplicateCanonicalModules
          .map(
            (module) =>
                '${module.firestoreId ?? 'local:${module.id}'}@isar:${module.id}',
          )
          .join(', ');
      throw StateError(
        'Cannot complete planned job: distinct local rows claim the same '
        'canonical module Firestore id. Resolve the duplicate without '
        'discarding evidence before closure. Rows: $ids',
      );
    }

    return resolution.modules;
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

    final executionId = id as int;
    final local = await isar.jobExecutions.get(executionId);
    if (local == null || local.isDeleted) {
      throw StateError('Planned job execution not found.');
    }
    if (!local.actionsReadResult.isValid) {
      throw StateError(
        'Saved planned-job action evidence needs repair before this job can be completed.',
      );
    }
    if (!local.responsesReadResult.isValid) {
      throw StateError(
        'Saved planned-job responses need repair before this job can be completed.',
      );
    }

    final executionFirestoreId = local.firestoreId?.trim();
    if (executionFirestoreId == null || executionFirestoreId.isEmpty) {
      throw StateError(
        'Cannot complete this planned job until it has a Firestore id. '
        'Run sync first, then try completion again.',
      );
    }

    if (!local.isSynced) {
      throw StateError(
        'Cannot complete this planned job until the execution header is synced. '
        'Run sync first so the server validates the current job state.',
      );
    }

    final localModules = await _loadModulesForExecution(local);
    for (final module in localModules) {
      if (!module.fieldDefinitionsReadResult.isValid) {
        throw StateError(
          'Saved field definitions for ${module.moduleTitle} need repair before this job can be completed.',
        );
      }
      if (!module.responsesReadResult.isValid) {
        throw StateError(
          'Saved responses for ${module.moduleTitle} need repair before this job can be completed.',
        );
      }
      if (!module.actionsReadResult.isValid) {
        throw StateError(
          'Saved actions for ${module.moduleTitle} need repair before this job can be completed.',
        );
      }
    }
    final unsyncedModules =
        localModules.where((module) => !module.isSynced).toList();
    if (unsyncedModules.isNotEmpty) {
      throw StateError(
        'Cannot complete this planned job until all module work is synced '
        '(${unsyncedModules.length} unsynced module(s)). Run sync first.',
      );
    }

    // Local preflight keeps the existing immediate UX, but the Cloud Function
    // is the authority. The server re-loads job_modules and repeats the closure
    // guard before writing isCompleted=true with Admin SDK.
    PlannedJobClosureGuard.assertReady(localModules);

    final remote = await _serverCompletion.completeExecution(
      executionFirestoreId: executionFirestoreId,
      remarks: remarks,
      teamsInvolved: teamsInvolved,
      responses: responses,
      actions: actions,
      expectedCompletionVersion: local.version + 1,
    );

    await isar.writeTxn(() async {
      final current = await isar.jobExecutions.get(executionId);
      if (current == null) return;

      current
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..templatePackageId = _cleanOptionalText(remote.templatePackageId)
        ..templateVersionId = _cleanOptionalText(remote.templateVersionId)
        ..templateVersionNumber = remote.templateVersionNumber
        ..templateVersionLabel = _cleanOptionalText(remote.templateVersionLabel)
        ..templateContentHash = _cleanOptionalText(remote.templateContentHash)
        ..templatePackageCode = _cleanOptionalText(remote.templatePackageCode)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;

      await isar.jobExecutions.put(current);
    });
  }

  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async {
    return await isar.jobTemplates.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markTemplatesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.jobTemplates.getAll(
            ids,
          )).whereType<JobTemplate>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.jobTemplates.putAll(records);
    });
  }

  @override
  Future<void> markTemplatesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.jobTemplates.getAll(
            byId.keys.toList(),
          )).whereType<JobTemplate>().toList();
      final unchanged = <JobTemplate>[];
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
      if (unchanged.isNotEmpty) await isar.jobTemplates.putAll(unchanged);
    });
  }

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId) async {
    return await isar.jobTemplates
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertTemplateFromRemote(JobTemplate remote) async {
    if (remote.isDeleted) return;
    await isar.writeTxn(() async {
      remote
        ..component = _cleanOptionalText(remote.component)
        ..subsystem = _cleanOptionalText(remote.subsystem)
        ..hierarchyPath = _cleanOptionalStringList(remote.hierarchyPath)
        ..assetHierarchyRefJson = _cleanOptionalText(
          remote.assetHierarchyRefJson,
        )
        ..isSynced = true;
      remote.setFields(remote.parsedFields);
      await isar.jobTemplates.put(remote);
    });
  }

  @override
  Future<void> updateTemplateFromRemote(JobTemplate remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'job template',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local =
          await isar.jobTemplates
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced local template against remote tombstone in updateTemplateFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          local.isDeleted = true;
          local.deletedAt = remoteDeleteTime;
          local.deletedByUid = remote.deletedByUid;
          local.deletedByName = remote.deletedByName;
          local.deleteReason = remote.deleteReason;
          local.updatedAt = remote.updatedAt;
          local.version = remote.version;
          local.isSynced = true;
          await isar.jobTemplates.put(local);
        }
        return;
      }

      final bool isLocalUnsynced = !local.isSynced;
      final bool isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final bool isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..version = remote.version
        ..jobName = remote.jobName.trim()
        ..description = _cleanOptionalText(remote.description)
        ..applicableAssetType = remote.applicableAssetType
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..component = _cleanOptionalText(remote.component)
        ..subsystem = _cleanOptionalText(remote.subsystem)
        ..hierarchyPath = _cleanOptionalStringList(remote.hierarchyPath)
        ..assetHierarchyRefJson = _cleanOptionalText(
          remote.assetHierarchyRefJson,
        )
        ..createdByUid = _cleanOptionalText(remote.createdByUid)
        ..createdByName = _cleanOptionalText(remote.createdByName)
        ..isActive = remote.isActive
        ..isDeprecated = remote.isDeprecated
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;
      local.setFields(remote.parsedFields);
      await isar.jobTemplates.put(local);
    });
  }

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async {
    return await isar.jobExecutions.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markExecutionsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.jobExecutions.getAll(
            ids,
          )).whereType<JobExecution>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.jobExecutions.putAll(records);
    });
  }

  @override
  Future<void> markExecutionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.jobExecutions.getAll(
            byId.keys.toList(),
          )).whereType<JobExecution>().toList();
      final unchanged = <JobExecution>[];
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
      if (unchanged.isNotEmpty) await isar.jobExecutions.putAll(unchanged);
    });
  }

  @override
  Future<JobExecution?> getExecutionByFirestoreId(String firestoreId) async {
    return await isar.jobExecutions
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertExecutionFromRemote(JobExecution remote) async {
    if (remote.isDeleted) return;
    await isar.writeTxn(() async {
      remote
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..isSynced = true;
      await isar.jobExecutions.put(remote);
    });
  }

  @override
  Future<void> updateExecutionFromRemote(JobExecution remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'job execution',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced local execution against remote tombstone in updateExecutionFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          local.isDeleted = true;
          local.deletedAt = remoteDeleteTime;
          local.deletedByUid = remote.deletedByUid;
          local.deletedByName = remote.deletedByName;
          local.deleteReason = remote.deleteReason;
          local.updatedAt = remote.updatedAt;
          local.version = remote.version;
          local.isSynced = true;
          await isar.jobExecutions.put(local);
        }
        return;
      }

      final bool isLocalUnsynced = !local.isSynced;
      final bool isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final bool isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..templatePackageId = _cleanOptionalText(remote.templatePackageId)
        ..templateVersionId = _cleanOptionalText(remote.templateVersionId)
        ..templateVersionNumber = remote.templateVersionNumber
        ..templateVersionLabel = _cleanOptionalText(remote.templateVersionLabel)
        ..templateContentHash = _cleanOptionalText(remote.templateContentHash)
        ..templatePackageCode = _cleanOptionalText(remote.templatePackageCode)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;
      await isar.jobExecutions.put(local);
    });
  }

  @override
  Future<void> forceRebaseExecutionFromRemote(
    JobExecution remote, {
    String? reason,
  }) async {
    if (remote.firestoreId == null) return;

    await isar.writeTxn(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      local
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;

      await isar.jobExecutions.put(local);
    });

    if (reason != null && reason.trim().isNotEmpty) {
      debugPrint(
        '🛡️ Rebased local job execution from remote canonical state: '
        'firestoreId=${remote.firestoreId}, reason=$reason',
      );
    }
  }

  @override
  Future<PaginatedTemplateResult> getUpdatedTemplates({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateResult(records: [], lastDoc: null);
  }

  @override
  Future<PaginatedExecutionResult> getUpdatedExecutions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedExecutionResult(records: [], lastDoc: null);
  }

  @override
  Future<List<JobTemplate>> getTemplatesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <JobTemplate>[];
    for (final fid in ids) {
      final t =
          await isar.jobTemplates.filter().firestoreIdEqualTo(fid).findFirst();
      if (t != null) results.add(t);
    }
    return results;
  }

  @override
  Future<void> batchUpsertTemplates(List<JobTemplate> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.jobTemplates.put(r);
      }
    });
  }

  @override
  Future<List<JobExecution>> getExecutionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobExecution>[];
    for (final fid in ids) {
      final e =
          await isar.jobExecutions.filter().firestoreIdEqualTo(fid).findFirst();
      if (e != null) results.add(e);
    }
    return results;
  }

  @override
  Future<void> batchUpsertExecutions(List<JobExecution> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.jobExecutions.put(r);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
