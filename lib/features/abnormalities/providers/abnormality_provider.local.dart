part of 'abnormality_provider.dart';

class IsarAbnormalityRepository implements AbnormalityRepository {
  static const _uuid = Uuid();

  final AuditRepository _auditRepo;

  IsarAbnormalityRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  IsarCollection<AbnormalityType> get _typeBox => isar.abnormalityTypes;

  IsarCollection<ChargeAbnormality> get _abnormalityBox =>
      isar.collection<ChargeAbnormality>();

  // ───────────────────────────────────────────────────────────
  // TYPE MASTER DATA
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<AbnormalityType>> watchActiveTypes() {
    return _typeBox
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .isActiveEqualTo(true)
        .watch(fireImmediately: true)
        .map((types) {
          types.sort(_sortTypes);
          return types;
        });
  }

  @override
  Stream<List<AbnormalityType>> watchAllTypes() {
    return _typeBox
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((types) {
          types.sort(_sortTypes);
          return types;
        });
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async {
    final types =
        await _typeBox
            .filter()
            .isDeletedEqualTo(false)
            .and()
            .isActiveEqualTo(true)
            .findAll();

    types.sort(_sortTypes);
    return types;
  }

  @override
  Future<List<AbnormalityType>> getAllTypes() async {
    final types = await _typeBox.filter().isDeletedEqualTo(false).findAll();

    types.sort(_sortTypes);
    return types;
  }

  @override
  Future<AbnormalityType?> getTypeById(dynamic id) async {
    final type = await _typeBox.get(id as int);
    if (type != null && type.isDeleted) return null;
    return type;
  }

  @override
  Future<AbnormalityType?> getTypeByFirestoreId(String firestoreId) async {
    final type =
        await _typeBox.filter().firestoreIdEqualTo(firestoreId).findFirst();

    if (type != null && type.isDeleted) return null;
    return type;
  }

  @override
  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    _validateTypeForSave(type);

    type.firestoreId ??= _uuid.v4();

    final existing =
        await _typeBox
            .filter()
            .firestoreIdEqualTo(type.firestoreId!)
            .findFirst();

    final beforeSnapshot = existing?.toAuditMap();

    if (existing != null) {
      type.id = existing.id;
      type.version = existing.version + 1;
    } else {
      type.version = type.version <= 0 ? 1 : type.version;
    }

    type.updatedAt = DateTime.now();
    type.isSynced = false;

    await isar.writeTxn(() async {
      await _typeBox.put(type);
    });

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId ?? type.id.toString(),
        action:
            beforeSnapshot == null ? AuditAction.create : AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: type.toAuditMap(),
      );
    }
  }

  @override
  Future<void> updateType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    _validateTypeForSave(type);
    type.firestoreId ??= _uuid.v4();

    final existing =
        await _typeBox
            .filter()
            .firestoreIdEqualTo(type.firestoreId!)
            .findFirst();

    final beforeSnapshot = existing?.toAuditMap();

    if (existing != null) {
      type.id = existing.id;
    }

    type.markEdited(
      editedByUid: auditContext?.performedByUid ?? type.lastEditedByUid,
      editedByName: auditContext?.performedByName ?? type.lastEditedByName,
    );

    await isar.writeTxn(() async {
      await _typeBox.put(type);
    });

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId ?? type.id.toString(),
        action: AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: type.toAuditMap(),
      );
    }
  }

  @override
  Future<void> softDeleteType(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    final typeId = id as int;

    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final type = await _typeBox.get(typeId);
      if (type == null || type.isDeleted) return;

      beforeSnapshot = type.toAuditMap();

      type.softDelete(
        deletedByUid: auditContext?.performedByUid,
        deletedByName: auditContext?.performedByName,
        reason: auditContext?.reason?.name ?? auditContext?.reasonNotes,
      );

      await _typeBox.put(type);

      afterSnapshot = type.toAuditMap();
      entityId = type.firestoreId ?? type.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: entityId!,
        action: AuditAction.delete,
        context: auditContext,
        before: beforeSnapshot,
        after: afterSnapshot,
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTypeRemote(
    AbnormalityType remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'abnormality type',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await _typeBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced abnormality type against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..isActive = false
        ..deletedAt = remoteDeleteTime
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..lastEditedByUid = remote.lastEditedByUid
        ..lastEditedByName = remote.lastEditedByName
        ..isSynced = true;

      await _typeBox.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> seedDefaultTypes({required AppUser actor}) async {
    _requireCanManageAbnormalityTypes(actor);
    final createdByUid = actor.uid;
    final createdByName = actor.name;
    final existing =
        await _typeBox
            .filter()
            .firestoreIdEqualTo('RA_COIL_COLOUR')
            .findFirst();

    if (existing != null) return;

    final type = AbnormalityType.seedRaCoilColour(
      createdByUid: createdByUid,
      createdByName: createdByName,
    );

    await saveType(type, actor: actor);
  }

  // ───────────────────────────────────────────────────────────
  // CHARGE ABNORMALITIES
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  ) {
    return _abnormalityBox
        .filter()
        .sourceChargeNoEqualTo(sourceChargeNo)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((items) {
          items.sort(_sortAbnormalities);
          return items;
        });
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(
    int sourceChargeNo,
  ) async {
    final items =
        await _abnormalityBox
            .filter()
            .sourceChargeNoEqualTo(sourceChargeNo)
            .and()
            .isDeletedEqualTo(false)
            .findAll();

    items.sort(_sortAbnormalities);
    return items;
  }

  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async {
    final items =
        await _abnormalityBox.filter().isDeletedEqualTo(false).findAll();

    items.sort(_sortAbnormalities);
    return items;
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityById(dynamic id) async {
    final abnormality = await _abnormalityBox.get(id as int);
    if (abnormality != null && abnormality.isDeleted) return null;
    return abnormality;
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityByFirestoreId(
    String firestoreId,
  ) async {
    final abnormality =
        await _abnormalityBox
            .filter()
            .firestoreIdEqualTo(firestoreId)
            .findFirst();

    if (abnormality != null && abnormality.isDeleted) return null;
    return abnormality;
  }

  @override
  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanLogChargeAbnormality(actor);
    _validateAbnormalityForSave(abnormality);

    abnormality.firestoreId ??= _uuid.v4();
    abnormality.normalizeReannealingState();

    final existing =
        await _abnormalityBox
            .filter()
            .firestoreIdEqualTo(abnormality.firestoreId!)
            .findFirst();

    final beforeSnapshot = existing?.toAuditMap();

    if (existing != null) {
      abnormality.id = existing.id;
      abnormality.version = existing.version + 1;
    } else {
      abnormality.version = abnormality.version <= 0 ? 1 : abnormality.version;
    }

    abnormality.updatedAt = DateTime.now();
    abnormality.isSynced = false;

    await isar.writeTxn(() async {
      await _abnormalityBox.put(abnormality);
    });

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId ?? abnormality.id.toString(),
        action:
            beforeSnapshot == null ? AuditAction.create : AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: abnormality.toAuditMap(),
      );
    }
  }

  @override
  Future<void> updateAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanEditChargeAbnormality(actor);
    _validateAbnormalityForSave(abnormality);
    abnormality.firestoreId ??= _uuid.v4();

    final existing =
        await _abnormalityBox
            .filter()
            .firestoreIdEqualTo(abnormality.firestoreId!)
            .findFirst();

    final beforeSnapshot = existing?.toAuditMap();

    if (existing != null) {
      abnormality.id = existing.id;
    }

    abnormality.markEdited(
      editedByUid: auditContext?.performedByUid ?? abnormality.updatedByUid,
      editedByName: auditContext?.performedByName ?? abnormality.updatedByName,
    );

    await isar.writeTxn(() async {
      await _abnormalityBox.put(abnormality);
    });

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId ?? abnormality.id.toString(),
        action: AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: abnormality.toAuditMap(),
      );
    }
  }

  @override
  Future<void> softDeleteAbnormality(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanSoftDeleteChargeAbnormality(actor);
    final abnormalityId = id as int;

    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final abnormality = await _abnormalityBox.get(abnormalityId);
      if (abnormality == null || abnormality.isDeleted) return;

      beforeSnapshot = abnormality.toAuditMap();

      abnormality.softDelete(
        deletedByUid: auditContext?.performedByUid,
        deletedByName: auditContext?.performedByName,
        reason: auditContext?.reason?.name ?? auditContext?.reasonNotes,
      );

      await _abnormalityBox.put(abnormality);

      afterSnapshot = abnormality.toAuditMap();
      entityId = abnormality.firestoreId ?? abnormality.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: entityId!,
        action: AuditAction.delete,
        context: auditContext,
        before: beforeSnapshot,
        after: afterSnapshot,
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromAbnormalityRemote(
    ChargeAbnormality remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'charge abnormality',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await _abnormalityBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced charge abnormality against remote tombstone: '
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

      await _abnormalityBox.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  // ───────────────────────────────────────────────────────────
  // SYNC HELPERS
  // ───────────────────────────────────────────────────────────

  @override
  Future<List<AbnormalityType>> getUnsyncedTypes() async {
    return _typeBox.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities() async {
    return _abnormalityBox.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markTypeSynced(dynamic id, String firestoreId) async {
    final typeId = id as int;

    await isar.writeTxn(() async {
      final type = await _typeBox.get(typeId);
      if (type == null) return;

      type
        ..firestoreId = firestoreId
        ..isSynced = true;

      await _typeBox.put(type);
    });
  }

  @override
  Future<void> markAbnormalitySynced(dynamic id, String firestoreId) async {
    final abnormalityId = id as int;

    await isar.writeTxn(() async {
      final abnormality = await _abnormalityBox.get(abnormalityId);
      if (abnormality == null) return;

      abnormality
        ..firestoreId = firestoreId
        ..isSynced = true;

      await _abnormalityBox.put(abnormality);
    });
  }

  @override
  Future<void> markTypesSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    await isar.writeTxn(() async {
      final records =
          (await _typeBox.getAll(ids)).whereType<AbnormalityType>().toList();

      for (final record in records) {
        record.isSynced = true;
      }

      await _typeBox.putAll(records);
    });
  }

  @override
  Future<void> markTypesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await _typeBox.getAll(
            byId.keys.toList(),
          )).whereType<AbnormalityType>().toList();
      final unchanged = <AbnormalityType>[];
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
      if (unchanged.isNotEmpty) await _typeBox.putAll(unchanged);
    });
  }

  @override
  Future<void> markAbnormalitiesSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    await isar.writeTxn(() async {
      final records =
          (await _abnormalityBox.getAll(
            ids,
          )).whereType<ChargeAbnormality>().toList();

      for (final record in records) {
        record.isSynced = true;
      }

      await _abnormalityBox.putAll(records);
    });
  }

  @override
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await _abnormalityBox.getAll(
            byId.keys.toList(),
          )).whereType<ChargeAbnormality>().toList();
      final unchanged = <ChargeAbnormality>[];
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
      if (unchanged.isNotEmpty) await _abnormalityBox.putAll(unchanged);
    });
  }

  @override
  Future<PaginatedAbnormalityTypesResult> getUpdatedTypes({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    return PaginatedAbnormalityTypesResult(records: [], lastDoc: null);
  }

  @override
  Future<PaginatedChargeAbnormalitiesResult> getUpdatedAbnormalities({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    return PaginatedChargeAbnormalitiesResult(records: [], lastDoc: null);
  }

  @override
  Future<List<AbnormalityType>> getTypesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <AbnormalityType>[];

    for (final firestoreId in firestoreIds) {
      final local =
          await _typeBox.filter().firestoreIdEqualTo(firestoreId).findFirst();

      if (local != null) {
        results.add(local);
      }
    }

    return results;
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <ChargeAbnormality>[];

    for (final firestoreId in firestoreIds) {
      final local =
          await _abnormalityBox
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();

      if (local != null) {
        results.add(local);
      }
    }

    return results;
  }

  @override
  Future<void> insertTypeFromRemote(AbnormalityType remote) async {
    if (remote.isDeleted) return;

    remote.isSynced = true;

    await isar.writeTxn(() async {
      await _typeBox.put(remote);
    });
  }

  @override
  Future<void> updateTypeFromRemote(AbnormalityType remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'abnormality type',
              firestoreId: remote.firestoreId,
            )
            : null;

    await isar.writeTxn(() async {
      final local =
          await _typeBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced abnormality type against remote tombstone in updateTypeFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        local
          ..isDeleted = true
          ..isActive = false
          ..deletedAt = remoteDeleteTime
          ..deletedByUid = remote.deletedByUid
          ..deletedByName = remote.deletedByName
          ..deleteReason = remote.deleteReason
          ..updatedAt = remote.updatedAt
          ..version = remote.version
          ..lastEditedByUid = remote.lastEditedByUid
          ..lastEditedByName = remote.lastEditedByName
          ..isSynced = true;

        await _typeBox.put(local);
        return;
      }

      final isLocalUnsynced = !local.isSynced;
      final isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..code = remote.code
        ..title = remote.title
        ..description = remote.description
        ..category = remote.category
        ..severity = remote.severity
        ..applicableAssetTypeIndexes = remote.applicableAssetTypeIndexes
        ..suggestsReannealing = remote.suggestsReannealing
        ..isActive = remote.isActive
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..version = remote.version
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..createdByUid = remote.createdByUid
        ..createdByName = remote.createdByName
        ..lastEditedByUid = remote.lastEditedByUid
        ..lastEditedByName = remote.lastEditedByName
        ..isSynced = true;

      await _typeBox.put(local);
    });
  }

  @override
  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote) async {
    if (remote.isDeleted) return;

    remote.isSynced = true;

    await isar.writeTxn(() async {
      await _abnormalityBox.put(remote);
    });
  }

  @override
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'charge abnormality',
              firestoreId: remote.firestoreId,
            )
            : null;

    await isar.writeTxn(() async {
      final local =
          await _abnormalityBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced charge abnormality against remote tombstone in updateAbnormalityFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
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

        await _abnormalityBox.put(local);
        return;
      }

      final isLocalUnsynced = !local.isSynced;
      final isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..sourceChargeNo = remote.sourceChargeNo
        ..abnormalityTypeId = remote.abnormalityTypeId
        ..abnormalityTypeTitle = remote.abnormalityTypeTitle
        ..abnormalityTypeCode = remote.abnormalityTypeCode
        ..category = remote.category
        ..severity = remote.severity
        ..affectedAssetsJson = remote.affectedAssetsJson
        ..component = remote.component
        ..observedReason = remote.observedReason
        ..description = remote.description
        ..possibleRootReasonCategory = remote.possibleRootReasonCategory
        ..possibleRootReasonNotes = remote.possibleRootReasonNotes
        ..reannealingStatus = remote.reannealingStatus
        ..reannealedToChargeNo = remote.reannealedToChargeNo
        ..loggedAt = remote.loggedAt
        ..updatedAt = remote.updatedAt
        ..loggedByUid = remote.loggedByUid
        ..loggedByName = remote.loggedByName
        ..updatedByUid = remote.updatedByUid
        ..updatedByName = remote.updatedByName
        ..linkedTicketFirestoreId = remote.linkedTicketFirestoreId
        ..linkedExecutionFirestoreId = remote.linkedExecutionFirestoreId
        ..version = remote.version
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..isSynced = true;

      await _abnormalityBox.put(local);
    });
  }

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    if (records.isEmpty) return;

    await isar.writeTxn(() async {
      for (final record in records) {
        record.isSynced = true;
        await _typeBox.put(record);
      }
    });
  }

  @override
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records) async {
    if (records.isEmpty) return;

    await isar.writeTxn(() async {
      for (final record in records) {
        record.isSynced = true;
        await _abnormalityBox.put(record);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
