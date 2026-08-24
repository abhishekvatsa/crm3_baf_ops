// FILE: lib/features/maintenance/providers/maintenance_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../core/persistence/app_database.dart';
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
import '../data/remote_maintenance_timestamps.dart';
import '../../quality/domain/quality_warning_projection.dart';
import '../../directives/data/operational_directive_model.dart';
import '../domain/burner_lockout_case.dart';

part 'maintenance_provider.local.dart';
part 'maintenance_provider.copy.dart';
part 'maintenance_provider.reopen.dart';
part 'maintenance_provider.remote.dart';

const maintenancePairedBatchMaximum = 166;

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

String burnerRedHotDirectiveId(String ticketId) => 'burner_red_hot_$ticketId';

Map<String, dynamic>? burnerRedHotDirectiveProjection(
  MaintenanceRecord record,
) {
  final ticketId = record.firestoreId;
  final lockout = record.burnerLockoutCase;
  if (ticketId == null || lockout == null || !lockout.hasRedHotObservation) {
    return null;
  }
  final directiveId = burnerRedHotDirectiveId(ticketId);
  final positions = lockout.redHotPositions;
  final burnerList = positions.map((value) => 'B$value').join(', ');
  final createdAt = record.createdAt.toIso8601String();
  return <String, dynamic>{
    'firestoreId': directiveId,
    'title': 'Red-hot burner block: $burnerList',
    'description':
        'Furnace ${record.assetNumber} has a reported red-hot burner block at '
        '$burnerList. I&A must acknowledge, apply the approved plant procedure '
        'to take the affected burner position out of firing service, and record '
        'compliance. This directive does not actuate the PLC.',
    'assetType': AssetType.furnace.name,
    'assetNumber': record.assetNumber,
    'component': 'Burner block',
    'subsystem': 'Burner system',
    'tag': null,
    'hierarchyPath': <String>['Furnace', 'Combustion system', 'Burner block'],
    'directedTo': AppRole.seniorInstrumentation.name,
    'status': DirectiveStatus.open.name,
    'priority': DirectivePriority.critical.name,
    'createdByUid': record.loggedByUid,
    'createdByName': record.loggedByName,
    'issuedByUid': record.loggedByUid,
    'issuedByName': record.loggedByName,
    'issuedAt': createdAt,
    'isActive': true,
    'acknowledgedByUid': null,
    'acknowledgedByName': null,
    'acknowledgedAt': null,
    'closedByUid': null,
    'closedByName': null,
    'closedAt': null,
    'closedWithoutAcknowledgement': false,
    'remarks': null,
    'linkedMaintenanceFirestoreId': ticketId,
    'linkedExecutionFirestoreId': null,
    'metadataJson': jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'trigger': 'burnerBlockRedHot',
      'burnerPositions': positions,
      'automaticPlantActuation': false,
    }),
    'isDeleted': false,
    'deletedAt': null,
    'deletedByUid': null,
    'deletedByName': null,
    'deleteReason': null,
    'createdAt': createdAt,
    'updatedAt': createdAt,
    'version': 1,
  };
}

Map<String, dynamic>? burnerRedHotDirectiveProjectionForIssueMap(
  Map<String, dynamic> issue,
  String ticketId,
) {
  if (issue['classification'] != burnerLockoutClassification) return null;
  final lockout = BurnerLockoutCase.readOptionalSynchronizedFields(
    issue,
    source: 'maintenance replay $ticketId',
  );
  if (lockout == null || !lockout.hasRedHotObservation) return null;
  final assetNumber = issue['assetNumber'];
  final timestamps = readRemoteMaintenanceTimestamps(
    issue,
    source: 'maintenance replay $ticketId',
  );
  final createdAt = timestamps.createdAt;
  final loggedByUid = issue['loggedByUid'];
  if (assetNumber is! int || loggedByUid is! String) {
    throw StateError('Burner safety directive source evidence is incomplete.');
  }
  final record =
      MaintenanceRecord()
        ..firestoreId = ticketId
        ..assetType = AssetType.furnace
        ..assetNumber = assetNumber
        ..maintenanceType = MaintenanceType.breakdown
        ..classification = burnerLockoutClassification
        ..description = issue['description'] as String
        ..routedTo = RoutedTo.instrumentation
        ..component = 'Burner system'
        ..status = TicketStatus.open
        ..isResolved = false
        ..isCritical = true
        ..loggedByUid = loggedByUid
        ..loggedByName = issue['loggedByName'] as String?
        ..startDate = createdAt
        ..createdAt = createdAt
        ..updatedAt = createdAt;
  record.burnerLockoutCase = lockout;
  return burnerRedHotDirectiveProjection(record);
}

Map<String, dynamic>? burnerClosureEvidenceProjectionForIssueMap(
  Map<String, dynamic> issue,
  String ticketId,
) {
  if (issue['isResolved'] != true ||
      issue['burnerResolutionEvidence'] is! Map) {
    return null;
  }
  final version = issue['version'];
  final closedByUid = issue['closedByUid'];
  final updatedAt = issue['updatedAt'];
  if (version is! int || closedByUid is! String || updatedAt is! String) {
    throw StateError(
      'Burner closure projection source evidence is incomplete.',
    );
  }
  return <String, dynamic>{
    'firestoreId': ticketId,
    'sourceMaintenanceId': ticketId,
    'sourceVersion': version,
    'closedByUid': closedByUid,
    'burnerResolutionEvidence': Map<String, dynamic>.from(
      issue['burnerResolutionEvidence'] as Map,
    ),
    'updatedAt': updatedAt,
  };
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

abstract interface class ClosedTicketPageCursor {}

class _FirestoreClosedTicketPageCursor implements ClosedTicketPageCursor {
  const _FirestoreClosedTicketPageCursor(this.snapshot);

  final DocumentSnapshot snapshot;
}

class ClosedTicketPage {
  const ClosedTicketPage({required this.records, this.cursor});

  final List<MaintenanceRecord> records;
  final ClosedTicketPageCursor? cursor;
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
    BurnerLockoutResolution? burnerResolution,
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

  Future<ClosedTicketPage> getClosedTicketPage({
    int limit = 50,
    int offset = 0,
    ClosedTicketPageCursor? cursor,
  }) async {
    final records = await getClosedTickets(
      limit: limit,
      offset: offset,
      lastDocument:
          cursor is _FirestoreClosedTicketPageCursor ? cursor.snapshot : null,
    );
    return ClosedTicketPage(records: records);
  }

  Future<int> getClosedTicketsCount();

  Future<List<MaintenanceRecord>> getUnsyncedTickets();
  Future<void> markTicketSynced(dynamic id, String firestoreId);
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId);

  /// Reads exact command state from the server; local stores cannot prove it.
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  );

  Future<void> insertFromRemote(MaintenanceRecord remote);
  Future<void> updateFromRemote(MaintenanceRecord remote);

  /// Adopts exact command readback only at the unchanged local boundary or
  /// when another synchronization path already adopted that server version.
  Future<bool> applyMaintenanceIssueCommandReadback({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  });

  /// Applies an exact point-read refresh, including a canonical tombstone,
  /// only while the local row remains synchronized at the observed boundary.
  Future<bool> applyMaintenanceIssueServerRefresh({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  });

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

  /// Applies one field-scoped remote lifecycle replay when offline transitions
  /// collapsed into one dirty snapshot; local stores do not support it.
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  );

  /// Reads exact remote replay fields, including server-only burner evidence,
  /// to adjudicate an uncertain lifecycle write.
  Future<Map<String, dynamic>?>
  readRemoteMaintenanceLifecycleReplayFieldsForSync(String firestoreId);

  /// Adopts the complete authoritative server record after an idempotent create
  /// command. Local-only revision numbers are deliberately replaced by the
  /// server version, but only at the unchanged snapshot boundary.
  Future<bool> applyGovernedCreationServerStateForSync({
    required MaintenanceRecord remote,
    required SyncPushSnapshot expectedLocal,
  });

  /// Adopts the complete authoritative server record confirmed after a
  /// maintenance lifecycle replay. The local row is changed only if it still
  /// matches the snapshot used to construct the replay.
  Future<bool> applyMaintenanceLifecycleReplayReceiptForSync({
    required MaintenanceRecord remote,
    required SyncPushSnapshot expectedLocal,
  });

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

void _requireCanAttemptCloseMaintenanceTicket(AppUser actor) {
  if (!actor.canCloseMaintenanceTicket) {
    throw StateError('Not authorized to close maintenance tickets.');
  }
}

void _requireCanCloseMaintenanceTicket(
  AppUser actor,
  MaintenanceRecord record,
) {
  final laneRead = record.issueLanePlanReadResult;
  if (!laneRead.isValid) {
    throw StateError(
      'Saved accountable lane evidence needs reconciliation before closure.',
    );
  }
  final lanes = laneRead.value!.assignedLanes.map(RoutedTo.values.byName);
  if (!actor.canFinalizeMaintenanceIssue(lanes)) {
    throw StateError('Not authorized to close maintenance tickets.');
  }
}

void _requireCanReopenMaintenanceTicket(AppUser actor) {
  if (!actor.canReopenMaintenanceTicket) {
    throw StateError('Not authorized to reopen maintenance tickets.');
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
  if (!record.issueLanePlanReadResult.isValid) {
    throw StateError(
      'Saved accountable lane evidence needs repair before this ticket can be changed.',
    );
  }
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
