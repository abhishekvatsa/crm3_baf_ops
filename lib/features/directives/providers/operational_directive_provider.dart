// FILE: lib/features/directives/providers/operational_directive_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../core/persistence/app_database.dart';
import '../data/operational_directive_model.dart';
import '../data/remote_operational_directive_reader.dart';
import '../../auth/data/user_model.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';

part 'operational_directive_provider.local.dart';
part 'operational_directive_provider.remote.dart';

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
    DateTime? through,
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
