// FILE: lib/features/directives/providers/operational_directive_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../main.dart';
import '../data/operational_directive_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../auth/data/user_model.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
  if (value is! String) return fallback;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, dynamic value) {
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}

String? _cleanOptionalDirectiveText(String? value) {
  if (value == null) return null;
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

String _cleanRequiredDirectiveText(String value) => value.trim();

List<String>? _cleanDirectivePath(List<String>? value) {
  if (value == null) return null;
  final cleaned = value
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return cleaned.isEmpty ? null : cleaned;
}

int? _directiveIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime _readDirectiveDate(DateTime Function() read, DateTime fallback) {
  try {
    return read();
  } catch (_) {
    return fallback;
  }
}

/// Returns the compatible directive owner UID across legacy and new fields.
String? directiveOwnerUid(OperationalDirective directive) {
  return _cleanOptionalDirectiveText(directive.createdByUid) ??
      _cleanOptionalDirectiveText(directive.issuedByUid);
}

/// Returns the compatible directive owner display name across legacy and new fields.
String? directiveOwnerName(OperationalDirective directive) {
  return _cleanOptionalDirectiveText(directive.createdByName) ??
      _cleanOptionalDirectiveText(directive.issuedByName);
}

/// Returns true when the given user UID is recorded as creator/issuer.
bool directiveIssuedByUser(OperationalDirective directive, String uid) {
  final ownerUid = directiveOwnerUid(directive);
  return ownerUid != null && ownerUid == uid;
}

/// Applies the canonical directive visibility rule used by Home and Directives UI.
bool canUserSeeDirective(OperationalDirective directive, AppUser appUser) {
  if (appUser.isAdmin) return true;
  if (directiveIssuedByUser(directive, appUser.uid)) return true;
  return appUser.canBeTarget(directive.directedTo);
}

bool directiveAcknowledgedByUser(OperationalDirective directive, String uid) {
  final acknowledgedByUid = _cleanOptionalDirectiveText(
    directive.acknowledgedByUid,
  );
  return acknowledgedByUid != null && acknowledgedByUid == uid;
}

void _requireCanCreateDirective(AppUser actor, OperationalDirective directive) {
  if (!actor.canCreateDirective) {
    throw StateError('Not authorized to create operational directives.');
  }

  if (!actor.directiveTargets.contains(directive.directedTo)) {
    throw StateError('Not authorized to direct directives to this role.');
  }

  final ownerUid = directiveOwnerUid(directive);
  if (ownerUid != null && ownerUid != actor.uid) {
    throw StateError('Directive creator must match the signed-in user.');
  }
}

void _requireCanAdminMutateDirective(AppUser actor, String actionLabel) {
  final allowed =
      actionLabel == 'edit' ? actor.canEditDirective : actor.canDeleteDirective;

  if (!allowed) {
    throw StateError('Not authorized to $actionLabel directives.');
  }
}

void _requireCanAcknowledgeDirective(
  AppUser actor,
  OperationalDirective directive,
) {
  if (!actor.canAcknowledgeDirective(directive.directedTo)) {
    throw StateError('Not authorized to acknowledge this directive.');
  }

  if (directive.isClosed || directive.isDeleted) {
    throw StateError('Closed/deleted directives cannot be acknowledged.');
  }
}

void _requireCanCloseDirective(AppUser actor, OperationalDirective directive) {
  if (directive.isClosed || directive.isDeleted) {
    throw StateError('Directive is already closed or deleted.');
  }

  final canClose = actor.canCloseDirectiveInstance(
    createdByUid: directiveOwnerUid(directive),
    directedTo: directive.directedTo,
    acknowledgedByUid: directive.acknowledgedByUid,
  );

  if (!canClose) {
    throw StateError('Not authorized to close this directive.');
  }
}

/// Creates a detached copy that can be safely mutated before repository save.
OperationalDirective copyOperationalDirective(OperationalDirective source) {
  return OperationalDirective()
    ..id = source.id
    ..firestoreId = source.firestoreId
    ..isSynced = source.isSynced
    ..version = source.version
    ..isDeleted = source.isDeleted
    ..deletedAt = source.deletedAt
    ..deletedByUid = source.deletedByUid
    ..deletedByName = source.deletedByName
    ..deleteReason = source.deleteReason
    ..title = source.title
    ..description = source.description
    ..assetType = source.assetType
    ..assetNumber = source.assetNumber
    ..component = source.component
    ..subsystem = source.subsystem
    ..tag = source.tag
    ..hierarchyPath =
        source.hierarchyPath == null
            ? null
            : List<String>.from(source.hierarchyPath!)
    ..directedTo = source.directedTo
    ..status = source.status
    ..priority = source.priority
    ..createdByUid = source.createdByUid
    ..createdByName = source.createdByName
    ..issuedByUid = source.issuedByUid
    ..issuedByName = source.issuedByName
    ..issuedAt = source.issuedAt
    ..isActive = source.isActive
    ..acknowledgedByUid = source.acknowledgedByUid
    ..acknowledgedByName = source.acknowledgedByName
    ..acknowledgedAt = source.acknowledgedAt
    ..closedByUid = source.closedByUid
    ..closedByName = source.closedByName
    ..closedAt = source.closedAt
    ..closedWithoutAcknowledgement = source.closedWithoutAcknowledgement
    ..remarks = source.remarks
    ..linkedMaintenanceFirestoreId = source.linkedMaintenanceFirestoreId
    ..linkedExecutionFirestoreId = source.linkedExecutionFirestoreId
    ..createdAt = source.createdAt
    ..updatedAt = source.updatedAt
    ..metadataJson = source.metadataJson;
}

void _normalizeDirectiveIdentity(OperationalDirective directive) {
  final ownerUid = directiveOwnerUid(directive);
  final ownerName = directiveOwnerName(directive);

  directive.createdByUid = ownerUid;
  directive.issuedByUid = ownerUid;
  directive.createdByName = ownerName;
  directive.issuedByName = ownerName;

  final createdAt = _readDirectiveDate(
    () => directive.createdAt,
    directive.issuedAt ?? DateTime.now(),
  );
  directive.createdAt = createdAt;
  directive.issuedAt ??= createdAt;
}

void _normalizeDirectiveTextFields(OperationalDirective directive) {
  directive.title = _cleanRequiredDirectiveText(directive.title);
  directive.description = _cleanRequiredDirectiveText(directive.description);
  directive.component = _cleanOptionalDirectiveText(directive.component);
  directive.subsystem = _cleanOptionalDirectiveText(directive.subsystem);
  directive.tag = _cleanOptionalDirectiveText(directive.tag)?.toUpperCase();
  directive.remarks = _cleanOptionalDirectiveText(directive.remarks);
  directive.deletedByUid = _cleanOptionalDirectiveText(directive.deletedByUid);
  directive.deletedByName = _cleanOptionalDirectiveText(
    directive.deletedByName,
  );
  directive.deleteReason = _cleanOptionalDirectiveText(directive.deleteReason);
  directive.linkedMaintenanceFirestoreId = _cleanOptionalDirectiveText(
    directive.linkedMaintenanceFirestoreId,
  );
  directive.linkedExecutionFirestoreId = _cleanOptionalDirectiveText(
    directive.linkedExecutionFirestoreId,
  );
  directive.metadataJson = _cleanOptionalDirectiveText(directive.metadataJson);
  directive.hierarchyPath = _cleanDirectivePath(directive.hierarchyPath);

  if (directive.assetType == null) {
    directive.assetNumber = null;
  }
}

void _normalizeDirectiveLifecycle(OperationalDirective directive) {
  final updatedAt = _readDirectiveDate(
    () => directive.updatedAt,
    DateTime.now(),
  );

  if (directive.status == DirectiveStatus.closed) {
    directive.isActive = false;
    directive.closedAt ??= updatedAt;
    return;
  }

  directive.isActive = true;
  directive.closedByUid = null;
  directive.closedByName = null;
  directive.closedAt = null;
  directive.closedWithoutAcknowledgement = false;

  if (directive.status == DirectiveStatus.open) {
    directive.acknowledgedByUid = null;
    directive.acknowledgedByName = null;
    directive.acknowledgedAt = null;
  }
}

void _normalizeDirectiveForLocalWrite(
  OperationalDirective directive, {
  required bool bumpVersion,
  required bool markUnsynced,
}) {
  final now = DateTime.now();
  directive.createdAt = _readDirectiveDate(() => directive.createdAt, now);
  directive.updatedAt = now;
  if (directive.version < 1) directive.version = 1;
  if (bumpVersion) directive.version += 1;
  if (markUnsynced) directive.isSynced = false;
  _normalizeDirectiveIdentity(directive);
  _normalizeDirectiveTextFields(directive);
  _normalizeDirectiveLifecycle(directive);
}

void _normalizeDirectiveFromRemote(OperationalDirective directive) {
  final now = DateTime.now();
  directive.createdAt = _readDirectiveDate(() => directive.createdAt, now);
  directive.updatedAt = _readDirectiveDate(
    () => directive.updatedAt,
    directive.createdAt,
  );
  if (directive.version < 1) directive.version = 1;
  directive.isSynced = true;
  _normalizeDirectiveIdentity(directive);
  _normalizeDirectiveTextFields(directive);
  _normalizeDirectiveLifecycle(directive);
}

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECT
// ─────────────────────────────────────────────────────────────

class PaginatedDirectivesResult {
  final List<OperationalDirective> records;
  final DocumentSnapshot? lastDoc;

  PaginatedDirectivesResult({required this.records, this.lastDoc});
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class DirectiveRepository {
  // Core CRUD
  Future<void> saveDirective(
    OperationalDirective directive, {
    required AppUser actor,
  });
  Future<List<OperationalDirective>> getOpenDirectives();
  Future<List<OperationalDirective>> getAllDirectives();

  /// Reactive stream of all non-deleted directives, sorted by createdAt
  /// descending. Mirrors getAllDirectives() but keeps admin surfaces live.
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit});

  /// Reactive stream of non-deleted directives whose status is open or
  /// acknowledged, sorted by createdAt descending. Fires immediately with
  /// the current value, then on every local change.
  Stream<List<OperationalDirective>> watchOpenDirectives();

  // Update & Delete (for admin)
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  });
  Future<void> deleteDirective(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  /// Applies a tombstone received from a remote pull. Idempotent. Copies remote
  /// metadata verbatim, marks the local row clean only when the tombstone is
  /// actually applied, and returns a structured outcome so pull orchestration
  /// can surface preserved dirty-local conflicts instead of counting them as
  /// successful deletes. To be called by global_pull_service in place of
  /// deleteDirective(id) for pulled deletions.
  Future<RemoteTombstoneApplyResult> applyTombstoneFromDirectiveRemote(
    OperationalDirective remote,
  );

  // Lifecycle actions
  Future<void> acknowledgeDirective(dynamic id, {required AppUser actor});
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    bool wasUnacknowledged = false,
  });

  // Sync helpers
  Future<List<OperationalDirective>> getUnsyncedDirectives();
  Future<void> markDirectiveSynced(dynamic id, String firestoreId);
  Future<OperationalDirective?> getByFirestoreId(String firestoreId);
  Future<void> insertFromRemote(OperationalDirective remote);
  Future<void> updateFromRemote(OperationalDirective remote);

  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  // 🔥 Batch Sync Methods
  Future<List<OperationalDirective>> getDirectivesByFirestoreIds(
    List<String> firestoreIds,
  );
  Future<void> batchUpsertDirectives(List<OperationalDirective> records);
  Future<void> markDirectivesSynced(List<int> ids);
  Future<void> markDirectivesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  );
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

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

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
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
        ..deletedAt = remote.deletedAt ?? DateTime.now()
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
    _normalizeDirectiveFromRemote(remote);
    await isar.writeTxn(() async {
      await isar.operationalDirectives.put(remote);
    });
  }

  @override
  Future<void> updateFromRemote(OperationalDirective remote) async {
    if (remote.firestoreId == null) return;
    await isar.writeTxn(() async {
      final local =
          await isar.operationalDirectives
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      // 🔥 FIXED: replaced hard delete with tombstone copy
      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced directive against remote tombstone in updateFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          local.isDeleted = true;
          local.deletedAt = remote.deletedAt ?? DateTime.now();
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
      _normalizeDirectiveFromRemote(local);
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

class FirestoreDirectiveRepository implements DirectiveRepository {
  final AuditRepository _auditRepo;

  FirestoreDirectiveRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final _col = FirebaseFirestore.instance.collection('directives');

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
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    var query = _col
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => _mapDirective(doc)).toList(),
    );
  }

  @override
  Stream<List<OperationalDirective>> watchOpenDirectives() {
    return _col
        .where(
          'status',
          whereIn: [
            DirectiveStatus.open.name,
            DirectiveStatus.acknowledged.name,
          ],
        )
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => _mapDirective(doc)).toList());
  }

  @override
  Future<void> saveDirective(
    OperationalDirective d, {
    required AppUser actor,
  }) async {
    if (d.firestoreId == null) {
      throw Exception('firestoreId required');
    }
    _requireCanCreateDirective(actor, d);
    _normalizeDirectiveForLocalWrite(
      d,
      bumpVersion: false,
      markUnsynced: false,
    );
    d.isSynced = true;
    await _col
        .doc(d.firestoreId)
        .set(_directiveToMap(d), SetOptions(merge: true));
  }

  @override
  Future<List<OperationalDirective>> getOpenDirectives() async {
    final snap =
        await _col
            .where(
              'status',
              whereIn: [
                DirectiveStatus.open.name,
                DirectiveStatus.acknowledged.name,
              ],
            )
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map((doc) => _mapDirective(doc)).toList();
  }

  @override
  Future<List<OperationalDirective>> getAllDirectives() async {
    final snap = await _col.where('isDeleted', isEqualTo: false).get();
    return snap.docs.map((doc) => _mapDirective(doc)).toList();
  }

  @override
  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _col.orderBy('updatedAt');

    if (since != null) {
      query = query.where('updatedAt', isGreaterThan: since.toIso8601String());
    }

    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) {
      return PaginatedDirectivesResult(records: [], lastDoc: null);
    }

    return PaginatedDirectivesResult(
      records: snap.docs.map((doc) => _mapDirective(doc)).toList(),
      lastDoc: snap.docs.last,
    );
  }

  @override
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    if (directive.firestoreId == null) return;
    _requireCanAdminMutateDirective(actor, 'edit');
    _normalizeDirectiveForLocalWrite(
      directive,
      bumpVersion: false,
      markUnsynced: false,
    );
    directive.isSynced = true;
    final updateMap = <String, dynamic>{
      'title': directive.title,
      'description': directive.description,
      'directedTo': directive.directedTo.name,
      'assetType': directive.assetType?.name,
      'assetNumber': directive.assetNumber,
      'component': directive.component,
      'subsystem': directive.subsystem,
      'tag': directive.tag,
      'hierarchyPath': directive.hierarchyPath,
      'priority': directive.priority.name,
      'status': directive.status.name,
      'isActive': directive.isActive,
      'createdByUid': directive.createdByUid,
      'createdByName': directive.createdByName,
      'issuedByUid': directive.issuedByUid,
      'issuedByName': directive.issuedByName,
      'issuedAt': directive.issuedAt?.toIso8601String(),
      'acknowledgedByUid': directive.acknowledgedByUid,
      'acknowledgedByName': directive.acknowledgedByName,
      'acknowledgedAt': directive.acknowledgedAt?.toIso8601String(),
      'closedByUid': directive.closedByUid,
      'closedByName': directive.closedByName,
      'closedAt': directive.closedAt?.toIso8601String(),
      'closedWithoutAcknowledgement': directive.closedWithoutAcknowledgement,
      'remarks': directive.remarks,
      'linkedMaintenanceFirestoreId': directive.linkedMaintenanceFirestoreId,
      'linkedExecutionFirestoreId': directive.linkedExecutionFirestoreId,
      'metadataJson': directive.metadataJson,
      'updatedAt': directive.updatedAt.toIso8601String(),
      'version': FieldValue.increment(1),
    };
    await _col.doc(directive.firestoreId!).update(updateMap);
  }

  @override
  Future<void> deleteDirective(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanAdminMutateDirective(actor, 'delete');
    final docId = id as String;

    final beforeDoc = await _col.doc(docId).get();

    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    await _col.doc(docId).update({
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    });

    final afterSnapshot = {
      ...?beforeSnapshot,
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    };

    if (auditContext != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'directive',
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromDirectiveRemote(
    OperationalDirective remote,
  ) async {
    // No-op on web.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> acknowledgeDirective(
    dynamic id, {
    required AppUser actor,
  }) async {
    final firestoreId = id as String;
    final current = await getByFirestoreId(firestoreId);
    if (current == null) {
      throw StateError('Directive not found.');
    }
    _requireCanAcknowledgeDirective(actor, current);

    final now = DateTime.now().toIso8601String();
    await _col.doc(firestoreId).update({
      'status': DirectiveStatus.acknowledged.name,
      'isActive': true,
      'acknowledgedByUid': actor.uid,
      'acknowledgedByName': actor.name,
      'acknowledgedAt': now,
      'closedByUid': null,
      'closedByName': null,
      'closedAt': null,
      'closedWithoutAcknowledgement': false,
      'updatedAt': now,
      'version': FieldValue.increment(1),
    });
  }

  @override
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    bool wasUnacknowledged = false,
  }) async {
    final firestoreId = id as String;
    final current = await getByFirestoreId(firestoreId);
    if (current == null) {
      throw StateError('Directive not found.');
    }
    _requireCanCloseDirective(actor, current);

    final now = DateTime.now().toIso8601String();
    final cleanedRemarks = _cleanOptionalDirectiveText(remarks);
    final updateMap = <String, dynamic>{
      'status': DirectiveStatus.closed.name,
      'isActive': false,
      'closedByUid': actor.uid,
      'closedByName': actor.name,
      'closedAt': now,
      'closedWithoutAcknowledgement': wasUnacknowledged,
      'updatedAt': now,
      'version': FieldValue.increment(1),
    };
    if (cleanedRemarks != null) {
      updateMap['remarks'] = cleanedRemarks;
    }
    await _col.doc(firestoreId).update(updateMap);
  }

  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async => [];

  @override
  Future<void> markDirectiveSynced(dynamic id, String firestoreId) async {}

  @override
  Future<OperationalDirective?> getByFirestoreId(String firestoreId) async {
    final doc = await _col.doc(firestoreId).get();
    if (!doc.exists) return null;
    return _mapDirective(doc);
  }

  @override
  Future<void> insertFromRemote(OperationalDirective remote) async {}

  @override
  Future<void> updateFromRemote(OperationalDirective remote) async {}

  @override
  Future<List<OperationalDirective>> getDirectivesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <OperationalDirective>[];
    for (var i = 0; i < firestoreIds.length; i += 30) {
      final chunk = firestoreIds.sublist(
        i,
        i + 30 > firestoreIds.length ? firestoreIds.length : i + 30,
      );
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_mapDirective));
    }
    return results;
  }

  @override
  Future<void> batchUpsertDirectives(List<OperationalDirective> records) async {
    if (records.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _col.doc(record.firestoreId),
          _directiveToMap(record),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<void> markDirectivesSynced(List<int> ids) async {}

  @override
  Future<void> markDirectivesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  // ── Mapping helpers ─────────────────────────────────────────
  Map<String, dynamic> _directiveToMap(OperationalDirective d) {
    _normalizeDirectiveIdentity(d);
    _normalizeDirectiveTextFields(d);
    _normalizeDirectiveLifecycle(d);
    return {
      'title': d.title,
      'description': d.description,
      'assetType': d.assetType?.name,
      'assetNumber': d.assetNumber,
      'component': d.component,
      'subsystem': d.subsystem,
      'tag': d.tag,
      'hierarchyPath': d.hierarchyPath,
      'directedTo': d.directedTo.name,
      'status': d.status.name,
      'priority': d.priority.name,
      'createdByUid': d.createdByUid,
      'createdByName': d.createdByName,
      'issuedByUid': d.issuedByUid,
      'issuedByName': d.issuedByName,
      'issuedAt': d.issuedAt?.toIso8601String(),
      'isActive': d.isActive,
      'acknowledgedByUid': d.acknowledgedByUid,
      'acknowledgedByName': d.acknowledgedByName,
      'acknowledgedAt': d.acknowledgedAt?.toIso8601String(),
      'closedByUid': d.closedByUid,
      'closedByName': d.closedByName,
      'closedAt': d.closedAt?.toIso8601String(),
      'closedWithoutAcknowledgement': d.closedWithoutAcknowledgement,
      'remarks': d.remarks,
      'linkedMaintenanceFirestoreId': d.linkedMaintenanceFirestoreId,
      'linkedExecutionFirestoreId': d.linkedExecutionFirestoreId,
      'metadataJson': d.metadataJson,
      'isDeleted': d.isDeleted,
      'deletedAt': d.deletedAt?.toIso8601String(),
      'deletedByUid': d.deletedByUid,
      'deletedByName': d.deletedByName,
      'deleteReason': d.deleteReason,
      'createdAt': d.createdAt.toIso8601String(),
      'updatedAt': d.updatedAt.toIso8601String(),
      'version': d.version,
    };
  }

  OperationalDirective _mapDirective(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final directive =
        OperationalDirective()
          ..firestoreId = doc.id
          ..title = data['title'] ?? ''
          ..description = data['description'] ?? ''
          ..assetType = _enumByNameOrNull(AssetType.values, data['assetType'])
          ..assetNumber = _directiveIntOrNull(data['assetNumber'])
          ..component = data['component']
          ..subsystem = data['subsystem']
          ..tag = data['tag']
          ..hierarchyPath =
              data['hierarchyPath'] != null
                  ? List<String>.from(data['hierarchyPath'])
                  : null
          ..directedTo = _enumByNameOr(
            AppRole.values,
            data['directedTo'],
            AppRole.operations,
          )
          ..status = _enumByNameOr(
            DirectiveStatus.values,
            data['status'],
            DirectiveStatus.open,
          )
          ..priority = _enumByNameOr(
            DirectivePriority.values,
            data['priority'],
            DirectivePriority.medium,
          )
          ..createdByUid = data['createdByUid']
          ..createdByName = data['createdByName']
          ..issuedByUid = data['issuedByUid']
          ..issuedByName = data['issuedByName']
          ..issuedAt = _parseTimestamp(data['issuedAt'])
          ..isActive = data['isActive'] ?? true
          ..acknowledgedByUid = data['acknowledgedByUid']
          ..acknowledgedByName = data['acknowledgedByName']
          ..acknowledgedAt = _parseTimestamp(data['acknowledgedAt'])
          ..closedByUid = data['closedByUid']
          ..closedByName = data['closedByName']
          ..closedAt = _parseTimestamp(data['closedAt'])
          ..closedWithoutAcknowledgement =
              data['closedWithoutAcknowledgement'] ?? false
          ..remarks = data['remarks']
          ..linkedMaintenanceFirestoreId = data['linkedMaintenanceFirestoreId']
          ..linkedExecutionFirestoreId = data['linkedExecutionFirestoreId']
          ..metadataJson = data['metadataJson']
          ..isDeleted = data['isDeleted'] ?? false
          ..deletedAt = _parseTimestamp(data['deletedAt'])
          ..deletedByUid = data['deletedByUid']
          ..deletedByName = data['deletedByName']
          ..deleteReason = data['deleteReason']
          ..createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now()
          ..updatedAt =
              _parseTimestamp(data['updatedAt']) ??
              _parseTimestamp(data['createdAt']) ??
              DateTime.now()
          ..version = data['version'] ?? 1
          ..isSynced = true;
    _normalizeDirectiveFromRemote(directive);
    return directive;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);

    try {
      final dynamic maybeTimestamp = value;
      final converted = maybeTimestamp.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      // Unknown timestamp shape. Fall through to null.
    }

    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final isarDirectiveRepo = Provider<IsarDirectiveRepository>(
  (ref) => IsarDirectiveRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  ),
);

final firestoreDirectiveRepo = Provider<FirestoreDirectiveRepository>(
  (ref) => FirestoreDirectiveRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  ),
);

final directiveRepositoryProvider = Provider<DirectiveRepository>(
  (ref) =>
      kIsWeb ? ref.watch(firestoreDirectiveRepo) : ref.watch(isarDirectiveRepo),
);

final operationalDirectiveRepositoryProvider = directiveRepositoryProvider;
final activeDirectivesProvider = openDirectivesProvider;

// 🔥 CONVERTED: From FutureProvider to StreamProvider for live UI refresh
final openDirectivesProvider = StreamProvider<List<OperationalDirective>>(
  (ref) => ref.watch(directiveRepositoryProvider).watchOpenDirectives(),
);

/// Home badge count provider. On mobile/desktop it avoids subscribing Home to
/// the full open-directive list. The non-admin path counts the exact visibility
/// union by targeted role and issuer UID, de-duplicated by Isar id.
final visibleOpenDirectiveCountProvider = StreamProvider.family<int, AppUser>((
  ref,
  appUser,
) {
  if (kIsWeb) {
    return ref
        .watch(directiveRepositoryProvider)
        .watchOpenDirectives()
        .map(
          (directives) =>
              directives
                  .where((directive) => canUserSeeDirective(directive, appUser))
                  .length,
        )
        .distinct();
  }

  Future<int> countVisibleOpenDirectives() async {
    if (appUser.isAdmin) {
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
          .count();
    }

    final visibleIds = <Id>{};

    Future<void> addMatches(Future<List<OperationalDirective>> matches) async {
      final directives = await matches;
      visibleIds.addAll(directives.map((directive) => directive.id));
    }

    for (final role in appUser.roles.toSet()) {
      await addMatches(
        isar.operationalDirectives
            .filter()
            .group(
              (q) => q
                  .statusEqualTo(DirectiveStatus.open)
                  .or()
                  .statusEqualTo(DirectiveStatus.acknowledged),
            )
            .and()
            .isDeletedEqualTo(false)
            .and()
            .directedToEqualTo(role)
            .findAll(),
      );
    }

    await addMatches(
      isar.operationalDirectives
          .filter()
          .group(
            (q) => q
                .statusEqualTo(DirectiveStatus.open)
                .or()
                .statusEqualTo(DirectiveStatus.acknowledged),
          )
          .and()
          .isDeletedEqualTo(false)
          .and()
          .createdByUidEqualTo(appUser.uid)
          .findAll(),
    );

    await addMatches(
      isar.operationalDirectives
          .filter()
          .group(
            (q) => q
                .statusEqualTo(DirectiveStatus.open)
                .or()
                .statusEqualTo(DirectiveStatus.acknowledged),
          )
          .and()
          .isDeletedEqualTo(false)
          .and()
          .issuedByUidEqualTo(appUser.uid)
          .findAll(),
    );

    return visibleIds.length;
  }

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
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => countVisibleOpenDirectives())
      .distinct();
});

final directivesByComponentProvider =
    Provider.family<AsyncValue<List<OperationalDirective>>, String>((
      ref,
      component,
    ) {
      final normalizedComponent = component.trim().toLowerCase();
      return ref.watch(openDirectivesProvider).whenData((all) {
        return all
            .where(
              (d) =>
                  d.component != null &&
                  d.component!.trim().toLowerCase() == normalizedComponent,
            )
            .toList();
      });
    });

final highPriorityDirectivesProvider =
    Provider<AsyncValue<List<OperationalDirective>>>((ref) {
      return ref.watch(openDirectivesProvider).whenData((all) {
        return all
            .where(
              (d) =>
                  d.priority == DirectivePriority.high ||
                  d.priority == DirectivePriority.critical,
            )
            .toList();
      });
    });
