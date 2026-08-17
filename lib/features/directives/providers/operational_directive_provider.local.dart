part of 'operational_directive_provider.dart';

class IsarDirectiveRepository implements DirectiveRepository {
  final AuditRepository _auditRepo;

  IsarDirectiveRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  @override
  Future<void> saveDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    _requireCanCreateDirective(actor, directive);
    _normalizeDirectiveForLocalWrite(
      directive,
      bumpVersion: false,
      markUnsynced: true,
    );
    await isar.writeTxn(() async {
      await isar.operationalDirectives.put(directive);
    });
  }

  @override
  Future<List<OperationalDirective>> getOpenDirectives() async {
    try {
      return await isar.operationalDirectives
          .filter()
          .group(
            (q) => q
                .statusEqualTo(DirectiveStatus.open)
                .or()
                .statusEqualTo(DirectiveStatus.acknowledged),
          )
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .findAll();
    } catch (_) {
      final open =
          await isar.operationalDirectives
              .filter()
              .statusEqualTo(DirectiveStatus.open)
              .and()
              .isDeletedEqualTo(false)
              .findAll();
      final acknowledged =
          await isar.operationalDirectives
              .filter()
              .statusEqualTo(DirectiveStatus.acknowledged)
              .and()
              .isDeletedEqualTo(false)
              .findAll();
      final all = [...open, ...acknowledged];
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }
  }

  @override
  Stream<List<OperationalDirective>> watchOpenDirectives() {
    return isar.operationalDirectives
        .filter()
        .group(
          (q) => q
              .statusEqualTo(DirectiveStatus.open)
              .or()
              .statusEqualTo(DirectiveStatus.acknowledged),
        )
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((directives) {
          directives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return directives;
        });
  }

  @override
  Future<List<OperationalDirective>> getAllDirectives() async {
    try {
      return await isar.operationalDirectives
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .findAll();
    } catch (_) {
      final all =
          await isar.operationalDirectives
              .where()
              .filter()
              .isDeletedEqualTo(false)
              .findAll();
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }
  }

  @override
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    if (limit != null) {
      return isar.operationalDirectives
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.operationalDirectives
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((directives) {
          directives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return directives;
        });
  }

  @override
  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedDirectivesResult(records: [], lastDoc: null);
  }

  @override
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    _requireCanAdminMutateDirective(actor, 'edit');
    _normalizeDirectiveForLocalWrite(
      directive,
      bumpVersion: true,
      markUnsynced: true,
    );
    await isar.writeTxn(() async {
      await isar.operationalDirectives.put(directive);
    });
  }

  @override
  Future<void> deleteDirective(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanAdminMutateDirective(actor, 'delete');
    final directiveId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null && !d.isDeleted) {
        beforeSnapshot = d.toAuditMap();

        d.isDeleted = true;
        if (auditContext != null) {
          d.deletedAt = DateTime.now();
          d.deletedByUid = auditContext.performedByUid;
          d.deletedByName = auditContext.performedByName;
          d.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          d.updatedAt = DateTime.now();
          d.version += 1;
        } else {
          d.updatedAt = DateTime.now();
        }
        d.isSynced = false;
        await isar.operationalDirectives.put(d);

        afterSnapshot = d.toAuditMap();
        entityIdStr = d.firestoreId ?? d.id.toString();
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
            entityType: 'directive',
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromDirectiveRemote(
    OperationalDirective remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'operational directive',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.operationalDirectives
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local directive against remote tombstone: '
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
      await isar.operationalDirectives.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> acknowledgeDirective(
    dynamic id, {
    required AppUser actor,
  }) async {
    final directiveId = id as int;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null && !d.isDeleted) {
        _requireCanAcknowledgeDirective(actor, d);
        final now = DateTime.now();
        d.status = DirectiveStatus.acknowledged;
        d.acknowledgedByUid = actor.uid;
        d.acknowledgedByName = actor.name;
        d.acknowledgedAt = now;
        d.updatedAt = now;
        d.version += 1;
        d.isSynced = false;
        await isar.operationalDirectives.put(d);
      }
    });
  }

  @override
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    bool wasUnacknowledged = false,
  }) async {
    final directiveId = id as int;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null && !d.isDeleted) {
        _requireCanCloseDirective(actor, d);
        final now = DateTime.now();
        d.status = DirectiveStatus.closed;
        d.closedByUid = actor.uid;
        d.closedByName = actor.name;
        d.closedAt = now;
        d.closedWithoutAcknowledgement = wasUnacknowledged;
        if (remarks != null && remarks.isNotEmpty) {
          d.remarks = remarks;
        }
        d.updatedAt = now;
        d.version += 1;
        d.isSynced = false;
        await isar.operationalDirectives.put(d);
      }
    });
  }

  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async {
    return await isar.operationalDirectives
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markDirectiveSynced(dynamic id, String firestoreId) async {
    final directiveId = id as int;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null) {
        d.firestoreId = firestoreId;
        d.isSynced = true;
        await isar.operationalDirectives.put(d);
      }
    });
  }

  @override
  Future<OperationalDirective?> getByFirestoreId(String firestoreId) async {
    return await isar.operationalDirectives
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertFromRemote(OperationalDirective remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() async {
      await isar.operationalDirectives.put(remote);
    });
  }

  @override
  Future<void> updateFromRemote(OperationalDirective remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'operational directive',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local =
          await isar.operationalDirectives
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      // 🔥 FIXED: replaced hard delete with tombstone copy
      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced directive against remote tombstone in updateFromRemote: '
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
          await isar.operationalDirectives.put(local);
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
        ..title = remote.title
        ..description = remote.description
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..component = remote.component
        ..subsystem = remote.subsystem
        ..tag = remote.tag
        ..hierarchyPath = remote.hierarchyPath
        ..directedTo = remote.directedTo
        ..status = remote.status
        ..priority = remote.priority
        ..createdByUid = remote.createdByUid
        ..createdByName = remote.createdByName
        ..issuedByUid = remote.issuedByUid
        ..issuedByName = remote.issuedByName
        ..issuedAt = remote.issuedAt
        ..isActive = remote.isActive
        ..acknowledgedByUid = remote.acknowledgedByUid
        ..acknowledgedByName = remote.acknowledgedByName
        ..acknowledgedAt = remote.acknowledgedAt
        ..closedByUid = remote.closedByUid
        ..closedByName = remote.closedByName
        ..closedAt = remote.closedAt
        ..closedWithoutAcknowledgement = remote.closedWithoutAcknowledgement
        ..remarks = remote.remarks
        ..linkedMaintenanceFirestoreId = remote.linkedMaintenanceFirestoreId
        ..linkedExecutionFirestoreId = remote.linkedExecutionFirestoreId
        ..metadataJson = remote.metadataJson
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;
      await isar.operationalDirectives.put(local);
    });
  }

  @override
  Future<List<OperationalDirective>> getDirectivesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <OperationalDirective>[];
    // First try to fetch from Isar (fast path)
    for (final fid in firestoreIds) {
      final local =
          await isar.operationalDirectives
              .filter()
              .firestoreIdEqualTo(fid)
              .findFirst();
      if (local != null) results.add(local);
    }
    return results;
  }

  @override
  Future<void> batchUpsertDirectives(List<OperationalDirective> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.operationalDirectives.put(r);
      }
    });
  }

  @override
  Future<void> markDirectivesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.operationalDirectives.getAll(
            ids,
          )).whereType<OperationalDirective>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.operationalDirectives.putAll(records);
    });
  }

  @override
  Future<void> markDirectivesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.operationalDirectives.getAll(
            byId.keys.toList(),
          )).whereType<OperationalDirective>().toList();
      final unchanged = <OperationalDirective>[];
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
      if (unchanged.isNotEmpty) {
        await isar.operationalDirectives.putAll(unchanged);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
