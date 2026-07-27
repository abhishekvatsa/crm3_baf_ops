// FILE: lib/features/abnormalities/providers/abnormality_provider.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../main.dart';
import '../data/abnormality_model.dart';
import '../services/charge_abnormality_command_service.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../auth/data/user_model.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedAbnormalityTypesResult {
  final List<AbnormalityType> records;
  final fs.DocumentSnapshot? lastDoc;

  PaginatedAbnormalityTypesResult({required this.records, this.lastDoc});
}

class PaginatedChargeAbnormalitiesResult {
  final List<ChargeAbnormality> records;
  final fs.DocumentSnapshot? lastDoc;

  PaginatedChargeAbnormalitiesResult({required this.records, this.lastDoc});
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class AbnormalityRepository {
  // ── Type master data ───────────────────────────────────────

  Stream<List<AbnormalityType>> watchActiveTypes();
  Stream<List<AbnormalityType>> watchAllTypes();

  Future<List<AbnormalityType>> getActiveTypes();
  Future<List<AbnormalityType>> getAllTypes();
  Future<AbnormalityType?> getTypeById(dynamic id);
  Future<AbnormalityType?> getTypeByFirestoreId(String firestoreId);

  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> updateType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> softDeleteType(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<RemoteTombstoneApplyResult> applyTombstoneFromTypeRemote(
    AbnormalityType remote,
  );

  Future<void> seedDefaultTypes({required AppUser actor});

  // ── Charge abnormality events ──────────────────────────────

  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  );

  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(int sourceChargeNo);

  Future<List<ChargeAbnormality>> getAllAbnormalities();

  Future<ChargeAbnormality?> getAbnormalityById(dynamic id);

  Future<ChargeAbnormality?> getAbnormalityByFirestoreId(String firestoreId);

  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> updateAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> softDeleteAbnormality(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<RemoteTombstoneApplyResult> applyTombstoneFromAbnormalityRemote(
    ChargeAbnormality remote,
  );

  // ── Sync helpers: local push side ──────────────────────────

  Future<List<AbnormalityType>> getUnsyncedTypes();
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities();

  Future<void> markTypeSynced(dynamic id, String firestoreId);
  Future<void> markAbnormalitySynced(dynamic id, String firestoreId);

  Future<void> markTypesSynced(List<int> ids);
  Future<void> markTypesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> markAbnormalitiesSynced(List<int> ids);
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  );

  // ── Sync helpers: remote pull side ─────────────────────────

  Future<PaginatedAbnormalityTypesResult> getUpdatedTypes({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  });

  Future<PaginatedChargeAbnormalitiesResult> getUpdatedAbnormalities({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  });

  Future<List<AbnormalityType>> getTypesByFirestoreIds(
    List<String> firestoreIds,
  );

  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> firestoreIds,
  );

  Future<void> insertTypeFromRemote(AbnormalityType remote);
  Future<void> updateTypeFromRemote(AbnormalityType remote);

  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote);
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote);

  Future<void> batchUpsertTypes(List<AbnormalityType> records);
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records);
}

void _requireCanManageAbnormalityTypes(AppUser actor) {
  if (!actor.canManageAbnormalityTypes) {
    throw StateError('Not authorized to manage abnormality type master data.');
  }
}

void _requireCanLogChargeAbnormality(AppUser actor) {
  if (!actor.canLogChargeAbnormality) {
    throw StateError('Not authorized to log charge abnormalities.');
  }
}

void _requireCanEditChargeAbnormality(AppUser actor) {
  if (!actor.canEditChargeAbnormality) {
    throw StateError('Not authorized to edit charge abnormalities.');
  }
}

void _requireCanSoftDeleteChargeAbnormality(AppUser actor) {
  if (!actor.canSoftDeleteChargeAbnormality) {
    throw StateError('Not authorized to delete charge abnormalities.');
  }
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

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
    _ensureTypeDefaults(type);

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
    _ensureTypeDefaults(type);
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

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
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
        ..deletedAt = remote.deletedAt ?? DateTime.now()
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
    _ensureAbnormalityDefaults(abnormality);

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
    _ensureAbnormalityDefaults(abnormality);
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

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
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
        ..deletedAt = remote.deletedAt ?? DateTime.now()
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

    await isar.writeTxn(() async {
      final local =
          await _typeBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
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
          ..deletedAt = remote.deletedAt ?? DateTime.now()
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

    await isar.writeTxn(() async {
      final local =
          await _abnormalityBox
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced charge abnormality against remote tombstone in updateAbnormalityFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        local
          ..isDeleted = true
          ..deletedAt = remote.deletedAt ?? DateTime.now()
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

class FirestoreAbnormalityRepository implements AbnormalityRepository {
  static const _uuid = Uuid();

  final AuditRepository _auditRepo;

  FirestoreAbnormalityRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final fs.CollectionReference<Map<String, dynamic>> _types = fs
      .FirebaseFirestore
      .instance
      .collection('abnormality_types');

  final fs.CollectionReference<Map<String, dynamic>> _abnormalities = fs
      .FirebaseFirestore
      .instance
      .collection('charge_abnormalities');

  // ───────────────────────────────────────────────────────────
  // TYPE MASTER DATA
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<AbnormalityType>> watchActiveTypes() {
    return _types
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
                  .toList();

          records.sort(_sortTypes);
          return records;
        });
  }

  @override
  Stream<List<AbnormalityType>> watchAllTypes() {
    return _types.where('isDeleted', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      final records =
          snapshot.docs
              .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
              .toList();

      records.sort(_sortTypes);
      return records;
    });
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async {
    final snapshot =
        await _types
            .where('isDeleted', isEqualTo: false)
            .where('isActive', isEqualTo: true)
            .get();

    final records =
        snapshot.docs
            .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortTypes);
    return records;
  }

  @override
  Future<List<AbnormalityType>> getAllTypes() async {
    final snapshot = await _types.where('isDeleted', isEqualTo: false).get();

    final records =
        snapshot.docs
            .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortTypes);
    return records;
  }

  @override
  Future<AbnormalityType?> getTypeById(dynamic id) async {
    return getTypeByFirestoreId(id as String);
  }

  @override
  Future<AbnormalityType?> getTypeByFirestoreId(String firestoreId) async {
    final doc = await _types.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;

    final type = AbnormalityType.fromMap(doc.data()!, doc.id);
    if (type.isDeleted) return null;

    return type;
  }

  @override
  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    _ensureTypeDefaults(type);

    type.firestoreId ??= _uuid.v4();

    final beforeDoc = await _types.doc(type.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final isCreate = beforeSnapshot == null;

    type
      ..updatedAt = DateTime.now()
      ..version =
          isCreate ? (type.version <= 0 ? 1 : type.version) : type.version + 1
      ..isSynced = true;

    await _types
        .doc(type.firestoreId)
        .set(type.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId!,
        action: isCreate ? AuditAction.create : AuditAction.update,
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
    _ensureTypeDefaults(type);

    if (type.firestoreId == null) {
      throw Exception('firestoreId required for abnormality type update');
    }

    final beforeDoc = await _types.doc(type.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    type.markEdited(
      editedByUid: auditContext?.performedByUid ?? type.lastEditedByUid,
      editedByName: auditContext?.performedByName ?? type.lastEditedByName,
    );
    type.isSynced = true;

    await _types
        .doc(type.firestoreId)
        .set(type.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId!,
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
    final docId = id as String;

    final beforeDoc = await _types.doc(docId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'isActive': false,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
      'lastEditedByUid': auditContext?.performedByUid,
      'lastEditedByName': auditContext?.performedByName,
    };

    await _types.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {...?beforeSnapshot, ...updateData};

      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: docId,
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
    // No-op on web. Firestore is the source of truth.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> seedDefaultTypes({required AppUser actor}) async {
    _requireCanManageAbnormalityTypes(actor);
    final createdByUid = actor.uid;
    final createdByName = actor.name;
    final doc = await _types.doc('RA_COIL_COLOUR').get();
    if (doc.exists) return;

    final type = AbnormalityType.seedRaCoilColour(
      createdByUid: createdByUid,
      createdByName: createdByName,
    )..isSynced = true;

    await _types.doc('RA_COIL_COLOUR').set(type.toMap());
  }

  // ───────────────────────────────────────────────────────────
  // CHARGE ABNORMALITIES
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  ) {
    return _abnormalities
        .where('sourceChargeNo', isEqualTo: sourceChargeNo)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final records =
              snapshot.docs
                  .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
                  .toList();

          records.sort(_sortAbnormalities);
          return records;
        });
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(
    int sourceChargeNo,
  ) async {
    final snapshot =
        await _abnormalities
            .where('sourceChargeNo', isEqualTo: sourceChargeNo)
            .where('isDeleted', isEqualTo: false)
            .get();

    final records =
        snapshot.docs
            .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortAbnormalities);
    return records;
  }

  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async {
    final snapshot =
        await _abnormalities.where('isDeleted', isEqualTo: false).get();

    final records =
        snapshot.docs
            .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortAbnormalities);
    return records;
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityById(dynamic id) async {
    return getAbnormalityByFirestoreId(id as String);
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityByFirestoreId(
    String firestoreId,
  ) async {
    final doc = await _abnormalities.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;

    final abnormality = ChargeAbnormality.fromMap(doc.data()!, doc.id);
    if (abnormality.isDeleted) return null;

    return abnormality;
  }

  @override
  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanLogChargeAbnormality(actor);
    _ensureAbnormalityDefaults(abnormality);

    abnormality.firestoreId ??= _uuid.v4();
    abnormality.normalizeReannealingState();

    final beforeDoc = await _abnormalities.doc(abnormality.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final isCreate = beforeSnapshot == null;

    abnormality
      ..updatedAt = DateTime.now()
      ..version =
          isCreate
              ? (abnormality.version <= 0 ? 1 : abnormality.version)
              : abnormality.version + 1
      ..isSynced = true;

    await _abnormalities
        .doc(abnormality.firestoreId)
        .set(abnormality.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId!,
        action: isCreate ? AuditAction.create : AuditAction.update,
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
    _ensureAbnormalityDefaults(abnormality);

    if (abnormality.firestoreId == null) {
      throw Exception('firestoreId required for abnormality update');
    }

    final beforeDoc = await _abnormalities.doc(abnormality.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    abnormality.markEdited(
      editedByUid: auditContext?.performedByUid ?? abnormality.updatedByUid,
      editedByName: auditContext?.performedByName ?? abnormality.updatedByName,
    );
    abnormality.isSynced = true;

    await _abnormalities
        .doc(abnormality.firestoreId)
        .set(abnormality.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId!,
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
    final docId = id as String;

    final beforeDoc = await _abnormalities.doc(docId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
      'updatedByUid': auditContext?.performedByUid,
      'updatedByName': auditContext?.performedByName,
    };

    await _abnormalities.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {...?beforeSnapshot, ...updateData};

      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: docId,
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
    // No-op on web. Firestore is the source of truth.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  // ───────────────────────────────────────────────────────────
  // SYNC HELPERS
  // ───────────────────────────────────────────────────────────

  @override
  Future<List<AbnormalityType>> getUnsyncedTypes() async => [];

  @override
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities() async => [];

  @override
  Future<void> markTypeSynced(dynamic id, String firestoreId) async {}

  @override
  Future<void> markAbnormalitySynced(dynamic id, String firestoreId) async {}

  @override
  Future<void> markTypesSynced(List<int> ids) async {}

  @override
  Future<void> markTypesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> markAbnormalitiesSynced(List<int> ids) async {}

  @override
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<PaginatedAbnormalityTypesResult> getUpdatedTypes({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The abnormality-type pull has no server upper bound.',
        reasonCode: 'abnormality-type-server-anchor-missing',
      );
    }
    fs.Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _types,
      afterInclusive: since,
      throughInclusive: through,
    );

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return PaginatedAbnormalityTypesResult(records: [], lastDoc: null);
    }

    return PaginatedAbnormalityTypesResult(
      records:
          snapshot.docs
              .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snapshot.docs.last,
    );
  }

  @override
  Future<PaginatedChargeAbnormalitiesResult> getUpdatedAbnormalities({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The charge-abnormality pull has no server upper bound.',
        reasonCode: 'charge-abnormality-server-anchor-missing',
      );
    }
    fs.Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _abnormalities,
      afterInclusive: since,
      throughInclusive: through,
    );

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return PaginatedChargeAbnormalitiesResult(records: [], lastDoc: null);
    }

    return PaginatedChargeAbnormalitiesResult(
      records:
          snapshot.docs
              .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snapshot.docs.last,
    );
  }

  @override
  Future<List<AbnormalityType>> getTypesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <AbnormalityType>[];

    for (var i = 0; i < firestoreIds.length; i += 30) {
      final end = i + 30 > firestoreIds.length ? firestoreIds.length : i + 30;
      final chunk = firestoreIds.sublist(i, end);

      final snapshot =
          await _types.where(fs.FieldPath.documentId, whereIn: chunk).get();

      results.addAll(
        snapshot.docs.map((doc) => AbnormalityType.fromMap(doc.data(), doc.id)),
      );
    }

    return results;
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <ChargeAbnormality>[];

    for (var i = 0; i < firestoreIds.length; i += 30) {
      final end = i + 30 > firestoreIds.length ? firestoreIds.length : i + 30;
      final chunk = firestoreIds.sublist(i, end);

      final snapshot =
          await _abnormalities
              .where(fs.FieldPath.documentId, whereIn: chunk)
              .get();

      results.addAll(
        snapshot.docs.map(
          (doc) => ChargeAbnormality.fromMap(doc.data(), doc.id),
        ),
      );
    }

    return results;
  }

  @override
  Future<void> insertTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<void> updateTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote) async {}

  @override
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote) async {}

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    if (records.isEmpty) return;

    final batch = fs.FirebaseFirestore.instance.batch();

    for (final record in records) {
      if (record.firestoreId == null) continue;

      batch.set(
        _types.doc(record.firestoreId),
        record.toMap(),
        fs.SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records) async {
    if (records.isEmpty) return;

    final batch = fs.FirebaseFirestore.instance.batch();

    for (final record in records) {
      if (record.firestoreId == null) continue;

      batch.set(
        _abnormalities.doc(record.firestoreId),
        record.toMap(),
        fs.SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final isarAbnormalityRepoProvider = Provider<IsarAbnormalityRepository>(
  (ref) => IsarAbnormalityRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  ),
);

final firestoreAbnormalityRepoProvider =
    Provider<FirestoreAbnormalityRepository>(
      (ref) => FirestoreAbnormalityRepository(
        auditRepository: ref.read(auditRepositoryProvider),
      ),
    );

final chargeAbnormalityCommandServiceProvider =
    Provider<ChargeAbnormalityCommandService>(
      (ref) => ChargeAbnormalityCommandService(),
    );

final abnormalityRepositoryProvider = Provider<AbnormalityRepository>((ref) {
  if (kIsWeb) {
    return ref.watch(firestoreAbnormalityRepoProvider);
  }
  return ref.watch(isarAbnormalityRepoProvider);
});

final activeAbnormalityTypesProvider = StreamProvider<List<AbnormalityType>>((
  ref,
) {
  return ref.watch(abnormalityRepositoryProvider).watchActiveTypes();
});

final allAbnormalityTypesProvider = StreamProvider<List<AbnormalityType>>((
  ref,
) {
  return ref.watch(abnormalityRepositoryProvider).watchAllTypes();
});

final abnormalitiesForChargeProvider =
    StreamProvider.family<List<ChargeAbnormality>, int>((ref, sourceChargeNo) {
      return ref
          .watch(abnormalityRepositoryProvider)
          .watchAbnormalitiesForCharge(sourceChargeNo);
    });

// ─────────────────────────────────────────────────────────────
// PUBLIC COPY / NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

/// Creates a detached abnormality-type copy for safe edit dialogs.
AbnormalityType copyAbnormalityType(AbnormalityType source) {
  final copy =
      AbnormalityType()
        ..id = source.id
        ..firestoreId = source.firestoreId
        ..code = source.code
        ..title = source.title
        ..description = source.description
        ..category = source.category
        ..severity = source.severity
        ..applicableAssetTypeIndexes = [...source.applicableAssetTypeIndexes]
        ..suggestsReannealing = source.suggestsReannealing
        ..isActive = source.isActive
        ..isDeleted = source.isDeleted
        ..deletedAt = source.deletedAt
        ..deletedByUid = source.deletedByUid
        ..deletedByName = source.deletedByName
        ..deleteReason = source.deleteReason
        ..version = source.version
        ..isSynced = source.isSynced
        ..createdAt = source.createdAt
        ..updatedAt = source.updatedAt
        ..createdByUid = source.createdByUid
        ..createdByName = source.createdByName
        ..lastEditedByUid = source.lastEditedByUid
        ..lastEditedByName = source.lastEditedByName;

  _normalizeType(copy);
  return copy;
}

/// Creates a detached charge-abnormality copy for safe edit dialogs.
ChargeAbnormality copyChargeAbnormality(ChargeAbnormality source) {
  final copy =
      ChargeAbnormality()
        ..id = source.id
        ..firestoreId = source.firestoreId
        ..sourceChargeNo = source.sourceChargeNo
        ..abnormalityTypeId = source.abnormalityTypeId
        ..abnormalityTypeTitle = source.abnormalityTypeTitle
        ..abnormalityTypeCode = source.abnormalityTypeCode
        ..category = source.category
        ..severity = source.severity
        ..affectedAssetsJson = source.affectedAssetsJson
        ..component = source.component
        ..observedReason = source.observedReason
        ..description = source.description
        ..possibleRootReasonCategory = source.possibleRootReasonCategory
        ..possibleRootReasonNotes = source.possibleRootReasonNotes
        ..reannealingStatus = source.reannealingStatus
        ..reannealedToChargeNo = source.reannealedToChargeNo
        ..loggedAt = source.loggedAt
        ..updatedAt = source.updatedAt
        ..loggedByUid = source.loggedByUid
        ..loggedByName = source.loggedByName
        ..updatedByUid = source.updatedByUid
        ..updatedByName = source.updatedByName
        ..linkedTicketFirestoreId = source.linkedTicketFirestoreId
        ..linkedExecutionFirestoreId = source.linkedExecutionFirestoreId
        ..version = source.version
        ..isSynced = source.isSynced
        ..isDeleted = source.isDeleted
        ..deletedAt = source.deletedAt
        ..deletedByUid = source.deletedByUid
        ..deletedByName = source.deletedByName
        ..deleteReason = source.deleteReason;

  _normalizeAbnormality(copy);
  return copy;
}

// ─────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────

int _sortTypes(AbnormalityType a, AbnormalityType b) {
  final activeCompare = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
  if (activeCompare != 0) return activeCompare;

  final categoryCompare = a.category.name.compareTo(b.category.name);
  if (categoryCompare != 0) return categoryCompare;

  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int _sortAbnormalities(ChargeAbnormality a, ChargeAbnormality b) {
  final dateCompare = b.loggedAt.compareTo(a.loggedAt);
  if (dateCompare != 0) return dateCompare;

  return b.updatedAt.compareTo(a.updatedAt);
}

void _ensureTypeDefaults(AbnormalityType type) {
  final now = DateTime.now();

  try {
    type.code;
  } catch (_) {
    type.code = type.firestoreId ?? const Uuid().v4();
  }

  try {
    type.title;
  } catch (_) {
    type.title = 'Untitled Abnormality';
  }

  try {
    type.createdAt;
  } catch (_) {
    type.createdAt = now;
  }

  try {
    type.updatedAt;
  } catch (_) {
    type.updatedAt = now;
  }

  if (type.version <= 0) {
    type.version = 1;
  }

  _normalizeType(type);
}

void _ensureAbnormalityDefaults(ChargeAbnormality abnormality) {
  final now = DateTime.now();

  try {
    abnormality.sourceChargeNo;
  } catch (_) {
    abnormality.sourceChargeNo = 0;
  }

  try {
    abnormality.abnormalityTypeId;
  } catch (_) {
    abnormality.abnormalityTypeId = 'UNKNOWN';
  }

  try {
    abnormality.abnormalityTypeTitle;
  } catch (_) {
    abnormality.abnormalityTypeTitle = 'Unknown Abnormality';
  }

  try {
    abnormality.abnormalityTypeCode;
  } catch (_) {
    abnormality.abnormalityTypeCode = 'UNKNOWN';
  }

  try {
    abnormality.observedReason;
  } catch (_) {
    abnormality.observedReason = 'No reason recorded';
  }

  try {
    abnormality.loggedAt;
  } catch (_) {
    abnormality.loggedAt = now;
  }

  try {
    abnormality.updatedAt;
  } catch (_) {
    abnormality.updatedAt = now;
  }

  if (abnormality.version <= 0) {
    abnormality.version = 1;
  }

  _normalizeAbnormality(abnormality);
}

String? _cleanOptionalText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String _cleanRequiredText(String? value, String fallback) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

void _normalizeType(AbnormalityType type) {
  type
    ..code =
        _cleanRequiredText(
          type.code,
          type.firestoreId ?? const Uuid().v4(),
        ).trim().toUpperCase()
    ..title = _cleanRequiredText(type.title, 'Untitled Abnormality')
    ..description = _cleanOptionalText(type.description)
    ..deletedByUid = _cleanOptionalText(type.deletedByUid)
    ..deletedByName = _cleanOptionalText(type.deletedByName)
    ..deleteReason = _cleanOptionalText(type.deleteReason)
    ..createdByUid = _cleanOptionalText(type.createdByUid)
    ..createdByName = _cleanOptionalText(type.createdByName)
    ..lastEditedByUid = _cleanOptionalText(type.lastEditedByUid)
    ..lastEditedByName = _cleanOptionalText(type.lastEditedByName);

  type.applicableAssetTypeIndexes =
      type.applicableAssetTypeIndexes
          .where((index) => index >= 0 && index < AssetType.values.length)
          .toSet()
          .toList()
        ..sort();

  if (type.isDeleted) {
    type.isActive = false;
  } else {
    type.deletedAt = null;
    type.deletedByUid = null;
    type.deletedByName = null;
    type.deleteReason = null;
  }
}

void _normalizeAbnormality(ChargeAbnormality abnormality) {
  abnormality
    ..abnormalityTypeId = _cleanRequiredText(
      abnormality.abnormalityTypeId,
      'UNKNOWN',
    )
    ..abnormalityTypeCode = _cleanRequiredText(
      abnormality.abnormalityTypeCode,
      'UNKNOWN',
    )
    ..abnormalityTypeTitle = _cleanRequiredText(
      abnormality.abnormalityTypeTitle,
      'Unknown Abnormality',
    )
    ..component = _cleanOptionalText(abnormality.component)
    ..observedReason = _cleanRequiredText(
      abnormality.observedReason,
      'No reason recorded',
    )
    ..description = _cleanOptionalText(abnormality.description)
    ..possibleRootReasonNotes = _cleanOptionalText(
      abnormality.possibleRootReasonNotes,
    )
    ..loggedByUid = _cleanOptionalText(abnormality.loggedByUid)
    ..loggedByName = _cleanOptionalText(abnormality.loggedByName)
    ..updatedByUid = _cleanOptionalText(abnormality.updatedByUid)
    ..updatedByName = _cleanOptionalText(abnormality.updatedByName)
    ..linkedTicketFirestoreId = _cleanOptionalText(
      abnormality.linkedTicketFirestoreId,
    )
    ..linkedExecutionFirestoreId = _cleanOptionalText(
      abnormality.linkedExecutionFirestoreId,
    )
    ..deletedByUid = _cleanOptionalText(abnormality.deletedByUid)
    ..deletedByName = _cleanOptionalText(abnormality.deletedByName)
    ..deleteReason = _cleanOptionalText(abnormality.deleteReason);

  final uniqueAssets = <String, AffectedAssetRef>{};
  for (final asset in abnormality.affectedAssets) {
    if (asset.assetNumber <= 0) continue;
    uniqueAssets['${asset.assetType.name}:${asset.assetNumber}'] = asset;
  }
  abnormality.affectedAssets = uniqueAssets.values.toList();

  abnormality.normalizeReannealingState();

  if (!abnormality.isDeleted) {
    abnormality.deletedAt = null;
    abnormality.deletedByUid = null;
    abnormality.deletedByName = null;
    abnormality.deleteReason = null;
  }
}

Map<String, dynamic>? _sanitizeForAudit(Map<String, dynamic>? data) {
  if (data == null) return null;

  final sanitized = <String, dynamic>{};

  data.forEach((key, value) {
    if (value is fs.Timestamp) {
      sanitized[key] = value.toDate().toIso8601String();
    } else if (value is fs.DocumentReference) {
      sanitized[key] = value.path;
    } else if (value is fs.GeoPoint) {
      sanitized[key] = {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    } else if (value is Iterable) {
      sanitized[key] =
          value.map((item) {
            if (item is fs.Timestamp) return item.toDate().toIso8601String();
            if (item is fs.DocumentReference) return item.path;
            if (item is Map) return Map<String, dynamic>.from(item);
            return item;
          }).toList();
    } else if (value is Map) {
      sanitized[key] = Map<String, dynamic>.from(value);
    } else {
      sanitized[key] = value;
    }
  });

  return sanitized;
}

void _logAudit({
  required AuditRepository auditRepository,
  required String entityType,
  required String entityId,
  required AuditAction action,
  required AuditContext context,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) {
  unawaited(
    auditRepository.log(
      AuditEvent.fromContext(
        entityType: entityType,
        entityId: entityId,
        action: action,
        context: context.copyWith(before: before, after: after),
      ),
    ),
  );
}
