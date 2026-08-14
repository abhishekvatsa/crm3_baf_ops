// FILE: lib/features/maintenance/providers/maintenance_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore show Query;
import 'package:isar/isar.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/utils/combined_record_stream.dart';
import '../data/maintenance_model.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';
import '../data/remote_maintenance_reader.dart';
import '../../quality/domain/quality_warning_projection.dart';

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

class PaginatedMaintenanceResult {
  final List<MaintenanceRecord> records;
  final DocumentSnapshot? lastDoc;
  final int sourceDocumentCount;
  final int decodeErrorCount;

  PaginatedMaintenanceResult({
    required this.records,
    this.lastDoc,
    int? sourceDocumentCount,
    this.decodeErrorCount = 0,
  }) : sourceDocumentCount = sourceDocumentCount ?? records.length {
    if (decodeErrorCount < 0 ||
        this.sourceDocumentCount != records.length + decodeErrorCount) {
      throw ArgumentError(
        'Every maintenance source document must be accounted for as decoded '
        'or rejected.',
      );
    }
    if ((this.sourceDocumentCount == 0) != (lastDoc == null)) {
      throw ArgumentError(
        'A non-empty maintenance source page must retain its Firestore cursor.',
      );
    }
  }
}

bool maintenanceRecordOverlapsPeriod(
  MaintenanceRecord record,
  DateTime startInclusive,
  DateTime endExclusive,
) =>
    record.startDate.isBefore(endExclusive) &&
    (record.endDate == null || record.endDate!.isAfter(startInclusive));

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class MaintenanceRepository {
  Future<void> saveTicket(MaintenanceRecord record);
  Future<List<MaintenanceRecord>> getOpenTickets();
  Future<List<MaintenanceRecord>> getOpenTicketsByAssetType(AssetType type);
  Future<List<MaintenanceRecord>> getAllTickets();
  Future<List<MaintenanceRecord>> getTicketsForAsset(
    AssetType type,
    int number,
  );
  Future<MaintenanceRecord?> getTicketById(dynamic id);
  Future<void> updateTicket(MaintenanceRecord record, {required AppUser actor});

  // 🔥 REACTIVE STREAMS
  Stream<List<MaintenanceRecord>> watchOpenTickets();
  Stream<List<MaintenanceRecord>> watchAllTickets({int? limit});
  Stream<List<MaintenanceRecord>> watchTicketsOverlappingPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream<List<MaintenanceRecord>>.error(
        ArgumentError('Report start must precede report end.'),
      );
    }
    return watchAllTickets().map(
      (records) => records
          .where(
            (record) => maintenanceRecordOverlapsPeriod(
              record,
              startInclusive,
              endExclusive,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<MaintenanceRecord>> watchTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  });

  Stream<List<MaintenanceRecord>> watchOpenTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  });

  /// Reactive stream of non-deleted tickets strictly scoped to an asset type.
  /// Used by fleet reporting to avoid loading unrelated asset families.
  Stream<List<MaintenanceRecord>> watchTicketsByAssetType(
    AssetType type, {
    int? limit,
  });

  Stream<List<MaintenanceRecord>> watchOpenTicketsByAssetType(
    AssetType type, {
    int? limit,
  });

  Future<void> deleteTicket(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  /// Applies a tombstone received from a remote pull. Idempotent. Copies remote
  /// metadata verbatim, marks the local row clean only when the tombstone is
  /// actually applied, and returns a structured outcome so pull orchestration
  /// can surface preserved dirty-local conflicts instead of counting them as
  /// successful deletes. To be called by global_pull_service in place of
  /// deleteTicket(id) for pulled deletions.
  Future<RemoteTombstoneApplyResult> applyTombstoneFromMaintenanceRemote(
    MaintenanceRecord remote,
  );

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
  });

  Future<void> reopenTicket(
    dynamic id, {
    required AppUser actor,
    required String reopenedByUid,
    required String reopenedByName,
    String? reopenRemarks,
  });

  Future<List<MaintenanceRecord>> getClosedTickets({
    int limit = 50,
    int offset = 0,
    DocumentSnapshot? lastDocument, // 🔥 NEW: for Firestore cursor pagination
  });
  Future<int> getClosedTicketsCount();

  Future<List<MaintenanceRecord>> getUnsyncedTickets();
  Future<void> markTicketSynced(dynamic id, String firestoreId);
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId);
  Future<void> insertFromRemote(MaintenanceRecord remote);
  Future<void> updateFromRemote(MaintenanceRecord remote);
  Future<void> upsertTicket(MaintenanceRecord record);

  Future<PaginatedMaintenanceResult> getUpdatedTickets({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> firestoreIds,
  );
  Future<void> batchUpsertTickets(List<MaintenanceRecord> records);

  /// Applies one server-visible maintenance lifecycle replay step as a remote
  /// field-scoped merge. Used only by sync when offline local-first ticket
  /// actions collapsed create/close/reopen transitions into one dirty snapshot.
  /// Local repositories do not support this remote push primitive.
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  );

  Future<void> markTicketsSynced(List<int> ids);
  Future<void> markTicketsSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
}

// ─────────────────────────────────────────────────────────────
// INTERNAL NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalMaintenanceText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

void _normalizeManualMaintenanceUpdate(MaintenanceRecord record, DateTime now) {
  record
    ..component = _cleanOptionalMaintenanceText(record.component)
    ..subsystem = _cleanOptionalMaintenanceText(record.subsystem)
    ..tag = _cleanOptionalMaintenanceText(record.tag)
    ..classification = _cleanOptionalMaintenanceText(record.classification)
    ..otherDepartment = _cleanOptionalMaintenanceText(record.otherDepartment)
    ..remarks = _cleanOptionalMaintenanceText(record.remarks);

  if (record.status == TicketStatus.resolved) {
    record.isResolved = true;
    record.endDate ??= now;
    return;
  }

  record
    ..isResolved = false
    ..endDate = null
    ..closedByUid = null
    ..closedByName = null
    ..downtimeHours = null
    ..teamsInvolved = []
    ..actionsJson = '[]';
}

Object _nullableTextForFirestoreUpdate(String? value) {
  return _cleanOptionalMaintenanceText(value) ?? FieldValue.delete();
}

void _requireCanCloseMaintenanceTicket(AppUser actor) {
  if (!actor.canCloseMaintenanceTicket) {
    throw StateError('Not authorized to close maintenance tickets.');
  }
}

void _requireCanReopenMaintenanceTicket(AppUser actor) {
  if (!actor.canReopenMaintenanceTicket) {
    throw StateError('Not authorized to reopen maintenance tickets.');
  }
}

void _requireCanAdminEditMaintenanceTicket(AppUser actor) {
  if (!actor.canAdminEditMaintenanceTicket) {
    throw StateError('Not authorized to edit maintenance ticket fields.');
  }
}

void _requireCanSoftDeleteMaintenanceTicket(AppUser actor) {
  if (!actor.canSoftDeleteMaintenanceTicket) {
    throw StateError('Not authorized to delete maintenance tickets.');
  }
}

void _requireMaintenanceWorkflowAllowsAction(
  MaintenanceRecord record,
  String action,
) {
  if (!record.workflowDeferred) return;
  final lane = record.workflowTargetLaneKey?.trim();
  final suffix =
      lane == null || lane.isEmpty ? '' : ' for ${lane.toUpperCase()}';
  throw StateError(
    'Cannot $action while this ticket is deferred by maintenance workflow$suffix. '
    'Use the linked compliance request to reactivate or release it.',
  );
}

void _requireValidMaintenanceEvidence(MaintenanceRecord record) {
  if (!record.actionsReadResult.isValid) {
    throw StateError(
      'Saved action evidence needs repair before this ticket can be changed.',
    );
  }
  if (!record.resolutionHistoryReadResult.isValid) {
    throw StateError(
      'Saved resolution history needs repair before this ticket can be changed.',
    );
  }
}

void _requireMaintenanceWorkflowMapAllowsAction(
  Map<String, dynamic> data,
  String action,
) {
  if (data['workflowDeferred'] != true) return;
  final lane = data['workflowTargetLaneKey']?.toString().trim();
  final suffix =
      lane == null || lane.isEmpty ? '' : ' for ${lane.toUpperCase()}';
  throw StateError(
    'Cannot $action while this ticket is deferred by maintenance workflow$suffix. '
    'Use the linked compliance request to reactivate or release it.',
  );
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

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
  Future<void> updateTicket(
    MaintenanceRecord record, {
    required AppUser actor,
  }) async {
    _requireCanAdminEditMaintenanceTicket(actor);
    _requireMaintenanceWorkflowAllowsAction(record, 'edit this ticket');
    _requireValidMaintenanceEvidence(record);
    final now = DateTime.now();
    _normalizeManualMaintenanceUpdate(record, now);
    record.updatedAt = now;
    record.version += 1;
    record.isSynced = false;

    await isar.writeTxn(() async {
      await isar.maintenanceRecords.put(record);
    });
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
  }) async {
    _requireCanCloseMaintenanceTicket(actor);
    final ticketId = id as int;

    await isar.writeTxn(() async {
      final t = await isar.maintenanceRecords.get(ticketId);
      if (t != null && !t.isResolved && !t.isDeleted) {
        _requireMaintenanceWorkflowAllowsAction(t, 'resolve this ticket');
        _requireValidMaintenanceEvidence(t);
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

class FirestoreMaintenanceRepository extends MaintenanceRepository {
  final AuditRepository _auditRepo;

  FirestoreMaintenanceRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final _collection = FirebaseFirestore.instance.collection(
    'maintenance_records',
  );
  final _qualityWarnings = FirebaseFirestore.instance.collection(
    'quality_warnings',
  );

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
  Stream<List<MaintenanceRecord>> watchOpenTickets() {
    return _collection
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchAllTickets({int? limit}) {
    var query = _collection
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsOverlappingPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream<List<MaintenanceRecord>>.error(
        ArgumentError('Report start must precede report end.'),
      );
    }
    Stream<List<MaintenanceRecord>> decode(
      firestore.Query<Map<String, dynamic>> query,
    ) => query.snapshots().map(
      (snapshot) => snapshot.docs.map(_mapTicket).toList(growable: false),
    );

    final startedInPeriod = decode(
      _collection
          .where('isDeleted', isEqualTo: false)
          .where('startDate', isGreaterThanOrEqualTo: startInclusive)
          .where('startDate', isLessThan: endExclusive)
          .orderBy('startDate', descending: true),
    );
    final openCarryIn = decode(
      _collection
          .where('isResolved', isEqualTo: false)
          .where('isDeleted', isEqualTo: false)
          .where('startDate', isLessThan: startInclusive)
          .orderBy('startDate', descending: true),
    );
    final resolvedAcrossStart = decode(
      _collection
          .where('isResolved', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .where('endDate', isGreaterThan: startInclusive)
          .orderBy('endDate', descending: true),
    );

    return combineLatestUniqueRecordStreams<MaintenanceRecord>(
      streams: [startedInPeriod, openCarryIn, resolvedAcrossStart],
      identityOf: (record) => record.firestoreId ?? 'local:${record.id}',
      compare: (left, right) => right.startDate.compareTo(left.startDate),
    ).map(
      (records) => records
          .where(
            (record) => maintenanceRecordOverlapsPeriod(
              record,
              startInclusive,
              endExclusive,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Future<void> saveTicket(MaintenanceRecord record) async {
    _requireValidMaintenanceEvidence(record);
    if (record.firestoreId == null) {
      throw Exception('firestoreId cannot be null');
    }
    final ticketData = _ticketToMap(record);
    final warning = qualityWarningProjectionForIssue(record);
    if (warning == null) {
      await _collection
          .doc(record.firestoreId)
          .set(ticketData, SetOptions(merge: true));
      return;
    }
    final warningId = warning['warningId'] as String;
    final warningExists = (await _qualityWarnings.doc(warningId).get()).exists;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      _collection.doc(record.firestoreId),
      ticketData,
      SetOptions(merge: true),
    );
    if (!warningExists) batch.set(_qualityWarnings.doc(warningId), warning);
    await batch.commit();
  }

  @override
  Future<void> upsertTicket(MaintenanceRecord record) async =>
      await saveTicket(record);

  @override
  Future<List<MaintenanceRecord>> getOpenTickets() async {
    final snap =
        await _collection
            .where('isResolved', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<List<MaintenanceRecord>> getOpenTicketsByAssetType(
    AssetType type,
  ) async {
    final snap =
        await _collection
            .where('assetType', isEqualTo: type.name)
            .where('isResolved', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .get();
    final list = snap.docs.map(_mapTicket).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MaintenanceRecord>> getAllTickets() async {
    final snap =
        await _collection
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<PaginatedMaintenanceResult> getUpdatedTickets({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The maintenance pull has no server upper bound.',
        reasonCode: 'maintenance-server-anchor-missing',
      );
    }
    var query = globalPullServerWindowQuery(
      _collection,
      afterInclusive: since,
      throughInclusive: through,
    );
    query = query.limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.get();
    final records = <MaintenanceRecord>[];
    var decodeErrorCount = 0;
    for (final doc in snap.docs) {
      try {
        records.add(_mapTicket(doc));
      } catch (error) {
        decodeErrorCount++;
        debugPrint(
          'Rejected malformed maintenance document ${doc.id} during global '
          'pull (${error.runtimeType}).',
        );
      }
    }
    return PaginatedMaintenanceResult(
      records: records,
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      sourceDocumentCount: snap.docs.length,
      decodeErrorCount: decodeErrorCount,
    );
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsForAsset(
    AssetType type,
    int number,
  ) async {
    final snap =
        await _collection
            .where('assetType', isEqualTo: type.name)
            .where('assetNumber', isEqualTo: number)
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<MaintenanceRecord?> getTicketById(dynamic id) async {
    final doc = await _collection.doc(id as String).get();
    if (!doc.exists) return null;
    final ticket = _mapTicket(doc);
    return ticket.isDeleted ? null : ticket;
  }

  @override
  Future<void> updateTicket(
    MaintenanceRecord record, {
    required AppUser actor,
  }) async {
    _requireCanAdminEditMaintenanceTicket(actor);
    if (record.firestoreId == null) return;
    final current = await _collection.doc(record.firestoreId!).get();
    if (!current.exists || current.data() == null) return;
    _requireMaintenanceWorkflowMapAllowsAction(
      current.data()!,
      'edit this ticket',
    );
    final currentRecord = _mapTicket(current);
    _requireValidMaintenanceEvidence(currentRecord);
    _requireValidMaintenanceEvidence(record);
    final now = DateTime.now();
    _normalizeManualMaintenanceUpdate(record, now);

    final updateMap = <String, dynamic>{
      'assetType': record.assetType.name,
      'assetNumber': record.assetNumber,
      'description': record.description,
      'routedTo': record.routedTo.name,
      'maintenanceType': record.maintenanceType.name,
      'status': record.status.name,
      'isResolved': record.isResolved,
      'isCritical': record.isCritical,
      'component': _nullableTextForFirestoreUpdate(record.component),
      'subsystem': _nullableTextForFirestoreUpdate(record.subsystem),
      'tag': _nullableTextForFirestoreUpdate(record.tag),
      'assetHierarchyRefJson': _nullableTextForFirestoreUpdate(
        record.assetHierarchyRefJson,
      ),
      'classification': _nullableTextForFirestoreUpdate(record.classification),
      'otherDepartment': _nullableTextForFirestoreUpdate(
        record.otherDepartment,
      ),
      'remarks': _nullableTextForFirestoreUpdate(record.remarks),
      'actionsJson': record.actionsJson,
      'resolutionHistoryJson': record.resolutionHistoryJson,
      'updatedAt': now.toIso8601String(),
      'version': FieldValue.increment(1),
    };

    if (record.isResolved) {
      updateMap.addAll({
        'endDate': (record.endDate ?? now).toIso8601String(),
        'closedByUid': record.closedByUid,
        'closedByName': record.closedByName,
        'downtimeHours': record.downtimeHours,
        'teamsInvolved': record.teamsInvolved,
      });
      updateMap.removeWhere((key, value) => value == null);
    } else {
      updateMap.addAll({
        'endDate': FieldValue.delete(),
        'closedByUid': FieldValue.delete(),
        'closedByName': FieldValue.delete(),
        'downtimeHours': FieldValue.delete(),
        'teamsInvolved': [],
      });
    }

    await _collection.doc(record.firestoreId!).update(updateMap);
  }

  @override
  Future<void> deleteTicket(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanSoftDeleteMaintenanceTicket(actor);
    final docId = id as String;
    final doc = await _collection.doc(docId).get();
    if (!doc.exists || doc.data() == null) return;
    _requireMaintenanceWorkflowMapAllowsAction(
      doc.data()!,
      'delete this ticket',
    );

    final beforeSnapshot = _sanitizeForAudit(doc.data());
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final now = DateTime.now().toIso8601String();
    await _collection.doc(docId).update({
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    });

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'maintenance',
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromMaintenanceRemote(
    MaintenanceRecord remote,
  ) async {
    // No-op on web. Firestore is the source of truth and is observed via
    // .snapshots() — there is no separate "local store" to tombstone.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
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
  }) async {
    _requireCanCloseMaintenanceTicket(actor);
    final docId = id as String;
    final current = await _collection.doc(docId).get();
    if (!current.exists || current.data() == null) {
      throw StateError('Ticket not found.');
    }
    _requireMaintenanceWorkflowMapAllowsAction(
      current.data()!,
      'resolve this ticket',
    );
    _requireValidMaintenanceEvidence(_mapTicket(current));
    final now = (endDate ?? DateTime.now()).toIso8601String();
    final updateData = <String, dynamic>{
      'isResolved': true,
      'status': TicketStatus.resolved.name,
      'endDate': now,
      'closedByUid': closedByUid,
      'closedByName': closedByName,
      'remarks': remarks,
      'downtimeHours': downtimeHours,
      'teamsInvolved': teamsInvolved ?? [],
      'updatedAt': DateTime.now().toIso8601String(),
      'version': FieldValue.increment(1),
    };
    if (actions != null && actions.isNotEmpty) {
      updateData['actionsJson'] = ComponentAction.encode(actions);
    }
    await _collection.doc(docId).update(updateData);
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
    final docId = id as String;
    final doc = await _collection.doc(docId).get();
    if (!doc.exists || doc.data() == null) throw Exception('Ticket not found');
    final data = doc.data()!;
    _requireMaintenanceWorkflowMapAllowsAction(data, 'reopen this ticket');
    final current = _mapTicket(doc);
    _requireValidMaintenanceEvidence(current);
    final closedAt = current.endDate;
    if (!current.isResolved || closedAt == null) {
      throw Exception('Ticket is not resolved or has no end date');
    }
    if (DateTime.now().difference(closedAt).inHours > 4) {
      throw Exception('Cannot reopen: closed more than 4 hours ago');
    }

    final currentHistory = data['resolutionHistoryJson'];
    if (currentHistory is! String || currentHistory.trim().isEmpty) {
      throw const FormatException(
        'Ticket resolution history is absent or is not serialized JSON.',
      );
    }
    final historyPayload = readValidatedResolutionHistoryPayload(
      currentHistory,
      source: 'maintenance/$docId',
    );
    historyPayload.rows.add(
      ResolutionHistory.fromMap({
        'resolvedByUid': data['closedByUid'],
        'resolvedByName': data['closedByName'],
        'resolvedAt': closedAt,
        'actionsJson': data['actionsJson'] ?? '[]',
        'remarks': data['remarks'],
        'downtimeHours': data['downtimeHours'],
        'teamsInvolved': data['teamsInvolved'] ?? const <String>[],
      }, source: 'maintenance/$docId current closure').toMap(),
    );
    final newHistoryJson = jsonEncode(historyPayload.rows);

    await _collection.doc(docId).update({
      'isResolved': false,
      'status': TicketStatus.open.name,
      'endDate': FieldValue.delete(),
      'closedByUid': FieldValue.delete(),
      'closedByName': FieldValue.delete(),
      'downtimeHours': FieldValue.delete(),
      'actionsJson': '[]',
      'remarks': reopenRemarks,
      'teamsInvolved': [],
      'resolutionHistoryJson': newHistoryJson,
      'updatedAt': DateTime.now().toIso8601String(),
      'version': FieldValue.increment(1),
    });
  }

  @override
  Future<List<MaintenanceRecord>> getClosedTickets({
    int limit = 50,
    int offset = 0,
    DocumentSnapshot? lastDocument,
  }) async {
    // Build query
    var query = _collection
        .where('isResolved', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('endDate', descending: true)
        .limit(limit);

    // Apply cursor pagination if lastDocument provided
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<int> getClosedTicketsCount() async {
    final snap =
        await _collection
            .where('isResolved', isEqualTo: true)
            .where('isDeleted', isEqualTo: false)
            .count()
            .get();
    return snap.count ?? 0;
  }

  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async => [];
  @override
  Future<void> markTicketSynced(dynamic id, String firestoreId) async {}
  @override
  Future<void> insertFromRemote(MaintenanceRecord remote) async {}
  @override
  Future<void> updateFromRemote(MaintenanceRecord remote) async {}

  @override
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId) async {
    final doc = await _collection.doc(firestoreId).get();
    return doc.exists ? _mapTicket(doc) : null;
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <MaintenanceRecord>[];
    for (var i = 0; i < firestoreIds.length; i += 30) {
      final chunk = firestoreIds.sublist(
        i,
        i + 30 > firestoreIds.length ? firestoreIds.length : i + 30,
      );
      final snap =
          await _collection.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_mapTicket));
    }
    return results;
  }

  @override
  Future<void> batchUpsertTickets(List<MaintenanceRecord> records) async {
    const maximumPairedRecordsPerBatch = 250;
    for (
      var offset = 0;
      offset < records.length;
      offset += maximumPairedRecordsPerBatch
    ) {
      final chunk = records.sublist(
        offset,
        offset + maximumPairedRecordsPerBatch > records.length
            ? records.length
            : offset + maximumPairedRecordsPerBatch,
      );
      final warnings = <String, Map<String, dynamic>>{};
      for (final record in chunk) {
        final warning = qualityWarningProjectionForIssue(record);
        if (warning != null) {
          warnings[warning['warningId'] as String] = warning;
        }
      }
      final existingWarningIds = await _existingQualityWarningIds(
        warnings.keys,
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final record in chunk) {
        if (record.firestoreId != null) {
          batch.set(
            _collection.doc(record.firestoreId),
            _ticketToMap(record),
            SetOptions(merge: true),
          );
        }
      }
      for (final entry in warnings.entries) {
        if (!existingWarningIds.contains(entry.key)) {
          batch.set(_qualityWarnings.doc(entry.key), entry.value);
        }
      }
      await batch.commit();
    }
  }

  @override
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    final id = _cleanOptionalMaintenanceText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteMaintenanceLifecycleReplayStepForSync requires a non-empty firestoreId',
      );
    }

    // Field-scoped merge: the caller provides only the fields for one
    // maintenance lifecycle rule branch. This avoids pushing a collapsed final
    // dirty snapshot that skips the server-visible open/closed/open sequence.
    final warning = qualityWarningProjectionForIssueMap(stepData, id);
    if (warning == null) {
      await _collection.doc(id).set(stepData, SetOptions(merge: true));
      return;
    }
    final warningId = warning['warningId'] as String;
    final warningExists = (await _qualityWarnings.doc(warningId).get()).exists;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_collection.doc(id), stepData, SetOptions(merge: true));
    if (!warningExists) batch.set(_qualityWarnings.doc(warningId), warning);
    await batch.commit();
  }

  Future<Set<String>> _existingQualityWarningIds(
    Iterable<String> warningIds,
  ) async {
    final ids = warningIds.toSet().toList();
    final existing = <String>{};
    for (var index = 0; index < ids.length; index += 30) {
      final chunk = ids.sublist(
        index,
        index + 30 > ids.length ? ids.length : index + 30,
      );
      if (chunk.isEmpty) continue;
      final snapshot =
          await _qualityWarnings
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      existing.addAll(snapshot.docs.map((document) => document.id));
    }
    return existing;
  }

  @override
  Future<void> markTicketsSynced(List<int> ids) async {}

  @override
  Future<void> markTicketsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  // 🔥 FULL MAPPING (RESTORED)
  Map<String, dynamic> _ticketToMap(MaintenanceRecord t) => {
    ...t.qualityIntentSynchronizedFields,
    'firestoreId': t.firestoreId,
    'version': t.version,
    'assetType': t.assetType.name,
    'assetNumber': t.assetNumber,
    'component': t.component,
    'subsystem': t.subsystem,
    'tag': t.tag,
    'hierarchyPath': t.hierarchyPath,
    'assetHierarchyRefJson': t.assetHierarchyRefJson,
    'maintenanceType': t.maintenanceType.name,
    'classification': t.classification,
    'description': t.description,
    'routedTo': t.routedTo.name,
    'otherDepartment': t.otherDepartment,
    'status': t.status.name,
    'isResolved': t.isResolved,
    'isCritical': t.isCritical,
    'loggedByUid': t.loggedByUid,
    'loggedByName': t.loggedByName,
    'reportedBy': t.reportedBy,
    'acknowledgedByUid': t.acknowledgedByUid,
    'acknowledgedByName': t.acknowledgedByName,
    'acknowledgedAt': t.acknowledgedAt?.toIso8601String(),
    'closedByUid': t.closedByUid,
    'closedByName': t.closedByName,
    'teamsInvolved': t.teamsInvolved,
    'performedBy': t.performedBy,
    'remarks': t.remarks,
    'startDate': t.startDate.toIso8601String(),
    'endDate': t.endDate?.toIso8601String(),
    'downtimeHours': t.downtimeHours,
    'chargeNoAtEvent': t.chargeNoAtEvent,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'metadataJson': t.metadataJson,
    'actionsJson': t.actionsJson,
    'resolutionHistoryJson': t.resolutionHistoryJson,
    'isDeleted': t.isDeleted,
    'deletedAt': t.deletedAt?.toIso8601String(),
    'deletedByUid': t.deletedByUid,
    'deletedByName': t.deletedByName,
    'deleteReason': t.deleteReason,
  };

  MaintenanceRecord _mapTicket(DocumentSnapshot doc) {
    return readRemoteMaintenanceRecord(
      Map<String, dynamic>.from(doc.data() as Map),
      documentId: doc.id,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS (REACTIVE MIGRATION)
// ─────────────────────────────────────────────────────────────

final isarMaintenanceRepo = Provider<IsarMaintenanceRepository>((ref) {
  return IsarMaintenanceRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});
final firestoreMaintenanceRepo = Provider<FirestoreMaintenanceRepository>((
  ref,
) {
  return FirestoreMaintenanceRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) =>
      kIsWeb
          ? ref.watch(firestoreMaintenanceRepo)
          : ref.watch(isarMaintenanceRepo),
);

// 🔥 CONVERTED: From FutureProvider to StreamProvider
final openTicketsProvider = StreamProvider<List<MaintenanceRecord>>((ref) {
  return ref.watch(maintenanceRepositoryProvider).watchOpenTickets();
});

/// Home badge count provider. On mobile/desktop it avoids materialising the
/// full open-ticket list just to compute the badge count. List screens should
/// keep using [openTicketsProvider].
final visibleOpenTicketCountProvider = StreamProvider.family<int, AppUser>((
  ref,
  appUser,
) {
  if (kIsWeb) {
    return ref.watch(maintenanceRepositoryProvider).watchOpenTickets().map((
      tickets,
    ) {
      if (appUser.canSeeAllTickets) return tickets.length;
      return tickets
          .where((ticket) => ticket.loggedByUid == appUser.uid)
          .length;
    }).distinct();
  }

  if (appUser.canSeeAllTickets) {
    Future<int> countOpenTickets() {
      return isar.maintenanceRecords
          .filter()
          .isResolvedEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .count();
    }

    return isar.maintenanceRecords
        .filter()
        .isResolvedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => countOpenTickets())
        .distinct();
  }

  Future<int> countOwnOpenTickets() {
    return isar.maintenanceRecords
        .filter()
        .isResolvedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .loggedByUidEqualTo(appUser.uid)
        .count();
  }

  return isar.maintenanceRecords
      .filter()
      .isResolvedEqualTo(false)
      .and()
      .isDeletedEqualTo(false)
      .and()
      .loggedByUidEqualTo(appUser.uid)
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => countOwnOpenTickets())
      .distinct();
});

final allTicketsProvider = StreamProvider<List<MaintenanceRecord>>((ref) {
  return ref.watch(maintenanceRepositoryProvider).watchAllTickets();
});
