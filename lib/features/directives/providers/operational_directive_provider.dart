// FILE: lib/features/directives/providers/operational_directive_provider.dart

import 'dart:async';
import '../services/ordinary_directive_commands.dart';
import '../data/directive_population.dart';
export '../data/directive_population.dart';
export '../services/ordinary_directive_commands.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../../core/persistence/app_database.dart';
import '../data/operational_directive_model.dart';
import '../data/remote_operational_directive_reader.dart';
import '../data/governed_directive_acknowledgement.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

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
  final allowed = actionLabel == 'edit'
      ? actor.canEditDirective
      : actor.canDeleteDirective;

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
    ..hierarchyPath = source.hierarchyPath == null
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
  final title = _cleanRequiredDirectiveText(directive.title);
  final description = _cleanRequiredDirectiveText(directive.description);
  if (title.isEmpty || description.isEmpty) {
    throw const FormatException(
      'Directive title and description must contain visible text.',
    );
  }
  directive.title = title;
  directive.description = description;
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

OperationalDirective _ordinaryChange(
  OperationalDirective before,
  AppUser actor,
  String action, {
  OperationalDirective? draft,
  String? reason,
}) {
  if (before.isDeleted || before.isClosed) {
    throw StateError(
      'Completed or deleted instructions remain historical records.',
    );
  }
  final after = copyOperationalDirective(before);
  if (action == 'amend') {
    _requireCanAdminMutateDirective(actor, 'edit');
    if (draft == null || draft.version != before.version) {
      throw StateError(
        'The reviewed directive changed. Keep the draft and refresh.',
      );
    }
    if (!actor.directiveTargets.contains(draft.directedTo)) {
      throw StateError('Unsupported target role.');
    }
    after
      ..title = draft.title
      ..description = draft.description
      ..directedTo = draft.directedTo
      ..priority = draft.priority
      ..assetType = draft.assetType
      ..assetNumber = draft.assetNumber
      ..component = draft.component
      ..subsystem = draft.subsystem
      ..tag = draft.tag
      ..hierarchyPath = draft.hierarchyPath
      ..remarks = draft.remarks
      ..metadataJson = draft.metadataJson
      ..status = DirectiveStatus.open
      ..acknowledgedAt = null
      ..acknowledgedByUid = null
      ..acknowledgedByName = null;
  } else if (action == 'acknowledge') {
    _requireCanAcknowledgeDirective(actor, before);
    if (!before.isOpen) {
      throw StateError('Only an open instruction can be acknowledged.');
    }
    after
      ..status = DirectiveStatus.acknowledged
      ..acknowledgedByUid = actor.uid
      ..acknowledgedByName = actor.name;
  } else if (action == 'close') {
    _requireCanCloseDirective(actor, before);
    after
      ..status = DirectiveStatus.closed
      ..closedByUid = actor.uid
      ..closedByName = actor.name
      ..closedWithoutAcknowledgement = (before.acknowledgedAt == null)
      ..remarks = reason?.trim();
  } else if (action == 'delete') {
    _requireCanAdminMutateDirective(actor, 'delete');
    after
      ..isDeleted = true
      ..deletedByUid = actor.uid
      ..deletedByName = actor.name
      ..deleteReason = reason?.trim();
  }
  final now = DateTime.now().toUtc();
  if (now.isBefore(before.updatedAt)) {
    throw StateError(
      'The device clock precedes the current directive. Check its time.',
    );
  }
  after
    ..version = before.version + 1
    ..updatedAt = now;
  if (action == 'acknowledge') after.acknowledgedAt = now;
  if (action == 'close') after.closedAt = now;
  if (action == 'delete') after.deletedAt = now;
  _normalizeDirectiveTextFields(after);
  _normalizeDirectiveLifecycle(after);
  return after;
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

  final List<String> rejectedIds;
  final int rawCount;
  PaginatedDirectivesResult({
    required this.records,
    this.lastDoc,
    this.rejectedIds = const [],
    int? rawCount,
  }) : rawCount = rawCount ?? records.length;
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
  Future<void> acknowledgeDirective(
    dynamic id, {
    required AppUser actor,
    required int expectedVersion,
  });
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    required int expectedVersion,
    String? remarks,
    bool wasUnacknowledged = false,
  });
  Future<void> adoptServerDirectiveClosure({
    required String firestoreId,
    required int expectedBeforeVersion,
    required int committedVersion,
    required AppUser actor,
    required DateTime closedAt,
    required bool wasUnacknowledged,
    String? remarks,
  });

  // Sync helpers
  Future<List<OperationalDirective>> getUnsyncedDirectives();
  Future<void> markDirectiveSynced(dynamic id, String firestoreId);
  Future<OperationalDirective?> getByFirestoreId(String firestoreId);
  Future<RemoteRecordApplyResult<OperationalDirective>>
  applyDirectiveFromRemote(OperationalDirective remote);
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
final directiveReadHealthProvider = StreamProvider.family<bool, String>(
  (ref, uid) => DirectiveReadHealth.watch(uid),
);

final openDirectivesProvider = StreamProvider<List<OperationalDirective>>((
  ref,
) {
  final repo = ref.watch(directiveRepositoryProvider);
  if (repo is! IsarDirectiveRepository) return repo.watchOpenDirectives();
  final uid = ref.watch(currentAppUserProvider).value?.uid;
  final incomplete =
      uid == null ||
      (ref.watch(directiveReadHealthProvider(uid)).value ?? true);
  return repo.watchOpenDirectives().map(
    (rows) => DirectivePopulation(
      DecodedSnapshotBatch(
        records: rows,
        rejectedDocumentIds: const [],
        isFromCache: incomplete,
      ),
    ),
  );
});

/// Home badge count provider. On mobile/desktop it avoids subscribing Home to
/// the full open-directive list. The non-admin path counts the exact visibility
/// union by targeted role and issuer UID, de-duplicated by Isar id.
final visibleOpenDirectiveCountProvider = StreamProvider.family<int, AppUser>((
  ref,
  appUser,
) {
  if (kIsWeb) {
    return ref.watch(directiveRepositoryProvider).watchOpenDirectives().map((
      directives,
    ) {
      if (!directivesAreQualified(directives)) {
        throw StateError('Directive count is incomplete or unconfirmed.');
      }
      return directives
          .where((directive) => canUserSeeDirective(directive, appUser))
          .length;
    }).distinct();
  }

  final incomplete =
      ref.watch(directiveReadHealthProvider(appUser.uid)).value ?? true;
  if (incomplete) {
    return Stream<int>.error(
      StateError(
        'Directive count is unconfirmed while a pull needs attention.',
      ),
    );
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
