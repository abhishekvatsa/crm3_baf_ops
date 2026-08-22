part of 'maintenance_provider.dart';

class IsarMaintenanceRepository extends MaintenanceRepository {
  final AuditRepository _auditRepo;

  IsarMaintenanceRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  @override
  Future<void> saveTicket(MaintenanceRecord record) async {
    _requireValidMaintenanceEvidence(record);
    record.updatedAt = DateTime.now();
    record.version += 1;
    record.isSynced = false;

    await isar.writeTxn(() async {
      await isar.maintenanceRecords.put(record);
    });
  }

  @override
  Future<void> upsertTicket(MaintenanceRecord record) async {
    await saveTicket(record);
  }

  @override
  Future<List<MaintenanceRecord>> getOpenTickets() async {
    final results =
        await isar.maintenanceRecords
            .filter()
            .isResolvedEqualTo(false)
            .and()
            .isDeletedEqualTo(false)
            .findAll();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTickets() {
    return isar.maintenanceRecords
        .filter()
        .isResolvedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Stream<List<MaintenanceRecord>> watchAllTickets({int? limit}) {
    if (limit != null) {
      return isar.maintenanceRecords
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.maintenanceRecords
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.maintenanceRecords
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

    return isar.maintenanceRecords
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.maintenanceRecords
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .assetNumberEqualTo(number)
          .and()
          .isResolvedEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.maintenanceRecords
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isResolvedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.maintenanceRecords
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.maintenanceRecords
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.maintenanceRecords
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .isResolvedEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.maintenanceRecords
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .isResolvedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((tickets) {
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  @override
  Future<List<MaintenanceRecord>> getOpenTicketsByAssetType(
    AssetType type,
  ) async {
    final results =
        await isar.maintenanceRecords
            .filter()
            .assetTypeEqualTo(type)
            .and()
            .isResolvedEqualTo(false)
            .and()
            .isDeletedEqualTo(false)
            .findAll();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<MaintenanceRecord>> getAllTickets() async {
    return await isar.maintenanceRecords
        .filter()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsForAsset(
    AssetType type,
    int number,
  ) async {
    return await isar.maintenanceRecords
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  @override
  Future<MaintenanceRecord?> getTicketById(dynamic id) async {
    final ticket = await isar.maintenanceRecords.get(id as int);
    if (ticket != null && ticket.isDeleted) return null;
    return ticket;
  }

  @override
  Future<void> deleteTicket(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanSoftDeleteMaintenanceTicket(actor);
    final ticketId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final t = await isar.maintenanceRecords.get(ticketId);
      if (t != null && !t.isDeleted) {
        _requireMaintenanceWorkflowAllowsAction(t, 'delete this ticket');
        beforeSnapshot = t.toAuditMap();

        t.isDeleted = true;

        if (auditContext != null) {
          // User-initiated delete: full bookkeeping + version bump so
          // updateFromRemote reconciliation correctly identifies the delete
          // as the winner against concurrent peer edits.
          t.deletedAt = DateTime.now();
          t.deletedByUid = auditContext.performedByUid;
          t.deletedByName = auditContext.performedByName;
          t.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          t.version += 1;
        }
        // Else: legacy pull-replay path (until global_pull_service is switched
        // to applyTombstoneFromMaintenanceRemote). Minimal write only — remote
        // tombstone metadata is applied separately by updateFromRemote.

        t.updatedAt = DateTime.now();
        t.isSynced = false;

        await isar.maintenanceRecords.put(t);

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
            entityType: 'maintenance',
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromMaintenanceRemote(
    MaintenanceRecord remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'maintenance ticket',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.maintenanceRecords
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local ticket against remote tombstone: '
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
      await isar.maintenanceRecords.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> resolveTicket(
    dynamic id, {
    required AppUser actor,
    String? closedByUid,
    String? closedByName,
    String? remarks,
    double? downtimeHours,
    DateTime? endDate,
    List<String>? teamsInvolved,
    List<ComponentAction>? actions,
    BurnerLockoutResolution? burnerResolution,
  }) async {
    _requireCanCloseMaintenanceTicket(actor);
    final ticketId = id as int;

    await isar.writeTxn(() async {
      final t = await isar.maintenanceRecords.get(ticketId);
      if (t != null && !t.isResolved && !t.isDeleted) {
        _requireMaintenanceWorkflowAllowsAction(t, 'resolve this ticket');
        _requireValidMaintenanceEvidence(t);
        final lockout = t.burnerLockoutCase;
        if (lockout != null) {
          if (burnerResolution == null) {
            throw StateError(
              'Every affected burner needs a terminal outcome before closure.',
            );
          }
          validateBurnerResolutionEvidence(
            lockout: lockout,
            resolution: burnerResolution,
            actions: actions ?? const <ComponentAction>[],
          );
          t.burnerLockoutCase = lockout.withResolution(
            burnerResolution,
            actions: actions ?? const <ComponentAction>[],
          );
        } else if (burnerResolution != null) {
          throw StateError(
            'Burner outcomes cannot be attached to a standard issue.',
          );
        }
        t.isResolved = true;
        t.status = TicketStatus.resolved;
        t.endDate = endDate ?? DateTime.now();
        t.closedByUid = closedByUid;
        t.closedByName = closedByName;
        t.remarks = remarks;
        t.downtimeHours = downtimeHours;
        t.teamsInvolved = teamsInvolved ?? [];
        if (actions != null) t.actions = actions;
        t.updatedAt = DateTime.now();
        t.version += 1;
        t.isSynced = false;
        await isar.maintenanceRecords.put(t);
      }
    });
  }

  @override
  Future<void> reopenTicket(
    dynamic id, {
    required AppUser actor,
    required String reopenedByUid,
    required String reopenedByName,
    String? reopenRemarks,
  }) async {
    _requireCanReopenMaintenanceTicket(actor);
    final ticketId = id as int;

    await isar.writeTxn(() async {
      final t = await isar.maintenanceRecords.get(ticketId);
      if (t != null && t.isResolved && t.endDate != null && !t.isDeleted) {
        _requireMaintenanceWorkflowAllowsAction(t, 'reopen this ticket');
        _requireValidMaintenanceEvidence(t);
        final hoursSinceClosure = DateTime.now().difference(t.endDate!).inHours;
        if (hoursSinceClosure > 4) {
          throw Exception('Cannot reopen: closed more than 4 hours ago');
        }

        final historyEntry = ResolutionHistory(
          resolvedByUid: t.closedByUid,
          resolvedByName: t.closedByName,
          resolvedAt: t.endDate!,
          actionsJson: t.actionsJson,
          remarks: t.remarks,
          downtimeHours: t.downtimeHours,
          teamsInvolved: t.teamsInvolved,
        );

        final historyPayload = readValidatedResolutionHistoryPayload(
          t.resolutionHistoryJson,
          source: 'local maintenance ${t.id}',
        );
        historyPayload.rows.add(historyEntry.toMap());
        t.resolutionHistoryJson = jsonEncode(historyPayload.rows);

        t.isResolved = false;
        t.status = TicketStatus.open;
        t.endDate = null;
        t.closedByUid = null;
        t.closedByName = null;
        t.downtimeHours = null;
        t.actionsJson = '[]';
        final lockout = t.burnerLockoutCase;
        if (lockout != null) t.burnerLockoutCase = lockout.clearResolution();
        t.remarks = reopenRemarks;
        t.teamsInvolved = [];

        t.updatedAt = DateTime.now();
        t.version += 1;
        t.isSynced = false;

        await isar.maintenanceRecords.put(t);
      }
    });
  }

  @override
  Future<List<MaintenanceRecord>> getClosedTickets({
    int limit = 50,
    int offset = 0,
    DocumentSnapshot? lastDocument,
  }) async {
    return await isar.maintenanceRecords
        .filter()
        .isResolvedEqualTo(true)
        .and()
        .isDeletedEqualTo(false)
        .sortByEndDateDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Future<int> getClosedTicketsCount() async {
    return await isar.maintenanceRecords
        .filter()
        .isResolvedEqualTo(true)
        .and()
        .isDeletedEqualTo(false)
        .count();
  }

  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async {
    return await isar.maintenanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markTicketSynced(dynamic id, String firestoreId) async {
    final ticketId = id as int;
    await isar.writeTxn(() async {
      final ticket = await isar.maintenanceRecords.get(ticketId);
      if (ticket != null) {
        ticket.firestoreId = firestoreId;
        ticket.isSynced = true;
        await isar.maintenanceRecords.put(ticket);
      }
    });
  }

  @override
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId) async {
    return await isar.maintenanceRecords
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertFromRemote(MaintenanceRecord remote) async {
    if (remote.isDeleted) return;
    await isar.writeTxn(() async {
      remote.isSynced = true;
      await isar.maintenanceRecords.put(remote);
    });
  }

  @override
  Future<void> updateFromRemote(MaintenanceRecord remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'maintenance ticket',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local =
          await isar.maintenanceRecords
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      // 🔥 FIXED: replaced hard delete with soft tombstone copy
      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced local ticket against remote tombstone in updateFromRemote: '
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
          await isar.maintenanceRecords.put(local);
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
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..component = remote.component
        ..subsystem = remote.subsystem
        ..tag = remote.tag
        ..hierarchyPath = remote.hierarchyPath
        ..assetHierarchyRefJson = remote.assetHierarchyRefJson
        ..maintenanceType = remote.maintenanceType
        ..classification = remote.classification
        ..description = remote.description
        ..routedTo = remote.routedTo
        ..otherDepartment = remote.otherDepartment
        ..status = remote.status
        ..isResolved = remote.isResolved
        ..workflowDeferred = remote.workflowDeferred
        ..workflowQueueState = remote.workflowQueueState
        ..workflowAggregateId = remote.workflowAggregateId
        ..workflowComplianceId = remote.workflowComplianceId
        ..workflowOriginLaneKey = remote.workflowOriginLaneKey
        ..workflowTargetLaneKey = remote.workflowTargetLaneKey
        ..workflowConditionTypeKey = remote.workflowConditionTypeKey
        ..workflowConditionRef = remote.workflowConditionRef
        ..workflowDeferredAt = remote.workflowDeferredAt
        ..workflowDeferredByUid = remote.workflowDeferredByUid
        ..workflowDeferredByName = remote.workflowDeferredByName
        ..workflowReactivatedAt = remote.workflowReactivatedAt
        ..workflowReactivatedByUid = remote.workflowReactivatedByUid
        ..workflowReactivatedByName = remote.workflowReactivatedByName
        ..workflowReleasedAt = remote.workflowReleasedAt
        ..workflowReleasedByUid = remote.workflowReleasedByUid
        ..workflowReleasedByName = remote.workflowReleasedByName
        ..workflowCorrectionReason = remote.workflowCorrectionReason
        ..workflowUpdatedAt = remote.workflowUpdatedAt
        ..isCritical = remote.isCritical
        ..loggedByUid = remote.loggedByUid
        ..loggedByName = remote.loggedByName
        ..reportedBy = remote.reportedBy
        ..acknowledgedByUid = remote.acknowledgedByUid
        ..acknowledgedByName = remote.acknowledgedByName
        ..acknowledgedAt = remote.acknowledgedAt
        ..closedByUid = remote.closedByUid
        ..closedByName = remote.closedByName
        ..teamsInvolved = remote.teamsInvolved
        ..performedBy = remote.performedBy
        ..remarks = remote.remarks
        ..startDate = remote.startDate
        ..endDate = remote.endDate
        ..downtimeHours = remote.downtimeHours
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..metadataJson = remote.metadataJson
        ..actionsJson = remote.actionsJson
        ..resolutionHistoryJson = remote.resolutionHistoryJson
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;

      await isar.maintenanceRecords.put(local);
    });
  }

  @override
  Future<PaginatedMaintenanceResult> getUpdatedTickets({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedMaintenanceResult(records: [], lastDoc: null);
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <MaintenanceRecord>[];
    for (final fid in firestoreIds) {
      final local =
          await isar.maintenanceRecords
              .filter()
              .firestoreIdEqualTo(fid)
              .findFirst();
      if (local != null) results.add(local);
    }
    return results;
  }

  @override
  Future<void> batchUpsertTickets(List<MaintenanceRecord> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.maintenanceRecords.put(r);
      }
    });
  }

  @override
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) {
    throw UnsupportedError(
      'applyRemoteMaintenanceLifecycleReplayStepForSync is a remote sync '
      'primitive and is not supported by the local Isar maintenance repository.',
    );
  }

  @override
  Future<Map<String, dynamic>?>
  readRemoteMaintenanceLifecycleReplayFieldsForSync(String firestoreId) {
    throw UnsupportedError(
      'readRemoteMaintenanceLifecycleReplayFieldsForSync is a remote sync '
      'primitive and is not supported by the local Isar maintenance repository.',
    );
  }

  @override
  Future<bool> applyGovernedCreationReceiptForSync({
    required String firestoreId,
    required SyncPushSnapshot expectedLocal,
    required int serverCreateVersion,
    required DateTime serverAppliedAt,
    required bool hasPostCreateLifecycle,
  }) async {
    if (firestoreId.trim().isEmpty || serverCreateVersion < 1) {
      throw ArgumentError('Governed creation receipt evidence is invalid.');
    }
    final appliedAt = serverAppliedAt.toUtc();
    return isar.writeTxn<bool>(() async {
      final record = await isar.maintenanceRecords.get(expectedLocal.id);
      if (record == null ||
          record.firestoreId != firestoreId ||
          record.isDeleted ||
          !expectedLocal.matches(
            currentVersion: record.version,
            currentUpdatedAt: record.updatedAt,
          )) {
        return false;
      }

      record.createdAt = appliedAt;
      if (hasPostCreateLifecycle) {
        if (record.updatedAt.isBefore(appliedAt)) {
          record.updatedAt = appliedAt;
        }
      } else {
        record
          ..version = serverCreateVersion
          ..updatedAt = appliedAt;
      }
      record.isSynced = true;
      await isar.maintenanceRecords.put(record);
      return true;
    });
  }

  @override
  Future<bool> applyMaintenanceLifecycleReplayReceiptForSync({
    required String firestoreId,
    required SyncPushSnapshot expectedLocal,
    required int serverVersion,
    required DateTime serverUpdatedAt,
  }) async {
    if (firestoreId.trim().isEmpty ||
        serverVersion < 1 ||
        serverVersion < expectedLocal.version) {
      throw ArgumentError('Maintenance lifecycle replay receipt is invalid.');
    }
    final updatedAt = serverUpdatedAt.toUtc();
    return isar.writeTxn<bool>(() async {
      final record = await isar.maintenanceRecords.get(expectedLocal.id);
      if (record == null ||
          record.firestoreId != firestoreId ||
          record.isDeleted ||
          !expectedLocal.matches(
            currentVersion: record.version,
            currentUpdatedAt: record.updatedAt,
          )) {
        return false;
      }

      record
        ..version = serverVersion
        ..updatedAt = updatedAt
        ..isSynced = true;
      await isar.maintenanceRecords.put(record);
      return true;
    });
  }

  @override
  Future<void> markTicketsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.maintenanceRecords.getAll(
            ids,
          )).whereType<MaintenanceRecord>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.maintenanceRecords.putAll(records);
    });
  }

  @override
  Future<void> markTicketsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.maintenanceRecords.getAll(
            byId.keys.toList(),
          )).whereType<MaintenanceRecord>().toList();
      final unchanged = <MaintenanceRecord>[];
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
      if (unchanged.isNotEmpty) await isar.maintenanceRecords.putAll(unchanged);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION (FULL MAPPING RESTORED)
// ─────────────────────────────────────────────────────────────
