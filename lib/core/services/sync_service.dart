// FILE: lib/core/services/sync_service.dart

import 'dart:async' show unawaited;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../providers/sync_status_provider.dart';
import 'app_logger.dart';
import 'sync_push_snapshot.dart';
import 'sync_remote_freshness_policy.dart';

import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/providers/maintenance_provider.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import '../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../features/planned_maintenance/services/planned_job_server_completion_service.dart';
import '../../features/planned_maintenance/providers/job_diary_provider.dart';
import '../../features/planned_maintenance/providers/job_module_provider.dart';
import '../../features/planned_maintenance/providers/template_governance_provider.dart';
import '../../features/planned_maintenance/domain/baf_knowledge_repository.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/directives/providers/operational_directive_provider.dart';
import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/abnormalities/providers/abnormality_provider.dart';
import '../../features/audit/models/audit_event_model.dart';
import '../../features/audit/repositories/audit_repository.dart';
import '../../features/audit/providers/audit_provider.dart';

class SyncFailureDetail {
  final String entityType;
  final String entityId;
  final String message;
  final String? errorCode;
  final String? firestoreId;
  final bool isLikelyPermanent;
  final DateTime occurredAt;

  const SyncFailureDetail({
    required this.entityType,
    required this.entityId,
    required this.message,
    required this.occurredAt,
    this.errorCode,
    this.firestoreId,
    this.isLikelyPermanent = false,
  });

  String get shortLabel => '$entityType/$entityId';

  String get displayMessage {
    final code = errorCode == null ? '' : '[$errorCode] ';
    return '$code$message';
  }
}

class SyncPendingCounts {
  final int maintenanceTickets;
  final int jobTemplates;
  final int jobExecutions;
  final int jobDiaryEntries;
  final int jobModules;
  final int directives;
  final int abnormalityTypes;
  final int chargeAbnormalities;
  final int templatePackages;
  final int templateVersions;
  final int templatePublishAudits;
  final int knowledgeBaseRows;

  const SyncPendingCounts({
    this.maintenanceTickets = 0,
    this.jobTemplates = 0,
    this.jobExecutions = 0,
    this.jobDiaryEntries = 0,
    this.jobModules = 0,
    this.directives = 0,
    this.abnormalityTypes = 0,
    this.chargeAbnormalities = 0,
    this.templatePackages = 0,
    this.templateVersions = 0,
    this.templatePublishAudits = 0,
    this.knowledgeBaseRows = 0,
  });

  int get total =>
      maintenanceTickets +
      jobTemplates +
      jobExecutions +
      jobDiaryEntries +
      jobModules +
      directives +
      abnormalityTypes +
      chargeAbnormalities +
      templatePackages +
      templateVersions +
      templatePublishAudits +
      knowledgeBaseRows;

  bool get hasPending => total > 0;
}

// ─────────────────────────────────────────────────────────────
// SYNC SERVICE (BATCHED PUSH ENGINE) with tombstone support
// ─────────────────────────────────────────────────────────────

class SyncService {
  final MaintenanceRepository _maintenanceRepo;
  final MaintenanceRepository _firestoreMaintenance;

  final PlannedMaintenanceRepository _plannedRepo;
  final PlannedMaintenanceRepository _firestorePlanned;
  final PlannedJobServerCompletionService _serverCompletion;

  final JobDiaryRepository _jobDiaryRepo;
  final JobDiaryRepository _firestoreJobDiary;

  final JobModuleRepository _jobModuleRepo;
  final JobModuleRepository _firestoreJobModule;

  final TemplateGovernanceRepository _templateGovernanceRepo;
  final TemplateGovernanceRepository _firestoreTemplateGovernance;

  final DirectiveRepository _directiveRepo;
  final DirectiveRepository _firestoreDirective;

  final AbnormalityRepository _abnormalityRepo;
  final AbnormalityRepository _firestoreAbnormality;

  final BafKnowledgeRepository _knowledgeRepo;

  final AuditRepository _auditRepo;

  bool _isSyncing = false;

  int lastSuccessCount = 0;
  int lastFailureCount = 0;
  int lastConflictCount = 0;
  int lastFailureDetailOverflowCount = 0;
  static const int _maxFailureDetails = 12;
  final Set<String> lastConflictKeys = <String>{};
  final List<SyncFailureDetail> lastFailureDetails = <SyncFailureDetail>[];
  DateTime? lastSyncTime;

  SyncService({
    required MaintenanceRepository maintenanceRepo,
    required MaintenanceRepository firestoreMaintenance,
    required PlannedMaintenanceRepository plannedRepo,
    required PlannedMaintenanceRepository firestorePlanned,
    required PlannedJobServerCompletionService serverCompletion,
    required JobDiaryRepository jobDiaryRepo,
    required JobDiaryRepository firestoreJobDiary,
    required JobModuleRepository jobModuleRepo,
    required JobModuleRepository firestoreJobModule,
    required TemplateGovernanceRepository templateGovernanceRepo,
    required TemplateGovernanceRepository firestoreTemplateGovernance,
    required DirectiveRepository directiveRepo,
    required DirectiveRepository firestoreDirective,
    required AbnormalityRepository abnormalityRepo,
    required AbnormalityRepository firestoreAbnormality,
    required BafKnowledgeRepository knowledgeRepo,
    required AuditRepository auditRepository,
  }) : _maintenanceRepo = maintenanceRepo,
       _firestoreMaintenance = firestoreMaintenance,
       _plannedRepo = plannedRepo,
       _firestorePlanned = firestorePlanned,
       _serverCompletion = serverCompletion,
       _jobDiaryRepo = jobDiaryRepo,
       _firestoreJobDiary = firestoreJobDiary,
       _jobModuleRepo = jobModuleRepo,
       _firestoreJobModule = firestoreJobModule,
       _templateGovernanceRepo = templateGovernanceRepo,
       _firestoreTemplateGovernance = firestoreTemplateGovernance,
       _directiveRepo = directiveRepo,
       _firestoreDirective = firestoreDirective,
       _abnormalityRepo = abnormalityRepo,
       _firestoreAbnormality = firestoreAbnormality,
       _knowledgeRepo = knowledgeRepo,
       _auditRepo = auditRepository;

  Future<SyncPendingCounts> countPendingLocalWrites() async {
    final results = await Future.wait<int>([
      _maintenanceRepo.getUnsyncedTickets().then((items) => items.length),
      _plannedRepo.getUnsyncedTemplates().then((items) => items.length),
      _plannedRepo.getUnsyncedExecutions().then((items) => items.length),
      _jobDiaryRepo.getUnsyncedEntries().then((items) => items.length),
      _jobModuleRepo.getUnsyncedModules().then((items) => items.length),
      _templateGovernanceRepo.getUnsyncedPackages().then(
        (items) => items.length,
      ),
      _templateGovernanceRepo.getUnsyncedVersions().then(
        (items) => items.length,
      ),
      _templateGovernanceRepo.getUnsyncedAudits().then((items) => items.length),
      _knowledgeRepo.getUnsyncedRows().then((items) => items.length),
      _directiveRepo.getUnsyncedDirectives().then((items) => items.length),
      _abnormalityRepo.getUnsyncedTypes().then((items) => items.length),
      _abnormalityRepo.getUnsyncedAbnormalities().then((items) => items.length),
    ]);

    return SyncPendingCounts(
      maintenanceTickets: results[0],
      jobTemplates: results[1],
      jobExecutions: results[2],
      jobDiaryEntries: results[3],
      jobModules: results[4],
      templatePackages: results[5],
      templateVersions: results[6],
      templatePublishAudits: results[7],
      knowledgeBaseRows: results[8],
      directives: results[9],
      abnormalityTypes: results[10],
      chargeAbnormalities: results[11],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RETRY LOGIC
  // ─────────────────────────────────────────────────────────────

  Future<void> _retry(
    Future<void> Function() task, {
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    final rand = Random();

    while (true) {
      try {
        await task();
        return;
      } catch (e) {
        attempt++;

        if (attempt >= maxAttempts) rethrow;

        final baseDelay = Duration(seconds: 2 * attempt);
        final jitter = Duration(milliseconds: rand.nextInt(150));
        final delay = baseDelay + jitter;

        debugPrint('⚠️ Retry $attempt after ${delay.inMilliseconds}ms → $e');

        await Future.delayed(delay);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN ENTRY
  // ─────────────────────────────────────────────────────────────

  Future<void> syncAll() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    lastSuccessCount = 0;
    lastFailureCount = 0;
    lastConflictCount = 0;
    lastFailureDetailOverflowCount = 0;
    lastConflictKeys.clear();
    lastFailureDetails.clear();

    final start = DateTime.now();

    try {
      await _syncTickets();
      await _syncTemplates();
      await _syncTemplateGovernance();
      await _syncKnowledgeBase();
      // Push open/non-completion execution edits first so new assigned jobs exist.
      // Completed execution pushes are deferred until after job_modules are
      // pushed; the server closure function validates canonical remote modules.
      await _syncExecutions(skipCompletedClosures: true);
      await _syncJobDiaryEntries();
      await _syncJobModules();
      await _syncCompletedExecutionClosures();
      await _syncDirectives();

      // Master data first, then event records.
      await _syncAbnormalityTypes();
      await _syncChargeAbnormalities();

      if (!kIsWeb) {
        try {
          await _auditRepo.syncPendingAuditEvents();
        } catch (e, stackTrace) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'audit_event',
            entityId: 'pending_audit_batch',
            error: e,
          );
          debugPrint('❌ Audit sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
          unawaited(
            AppLogger.recordNonFatalError(
              e,
              stackTrace,
              reason: 'audit_event_sync_failed',
              context: const {
                'app_area': 'sync',
                'sync_phase': 'audit_push',
                'entity_type': 'audit_event',
              },
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Fatal error during syncAll: $e');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(
        AppLogger.recordNonFatalError(
          e,
          stackTrace,
          reason: 'push_sync_engine_failed',
          context: const {'app_area': 'sync', 'sync_phase': 'push_sync_all'},
        ),
      );

      rethrow;
    } finally {
      _isSyncing = false;
      lastSyncTime = DateTime.now();

      final duration = DateTime.now().difference(start).inMilliseconds;

      debugPrint(
        '📊 Sync complete → $lastSuccessCount success, $lastFailureCount failed (${duration}ms)',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────

  void _sortDeletesFirst(List<dynamic> items) {
    items.sort((a, b) {
      if (a.isDeleted && !b.isDeleted) return -1;
      if (!a.isDeleted && b.isDeleted) return 1;
      return a.updatedAt.compareTo(b.updatedAt);
    });
  }

  void _checkClockDrift(DateTime updatedAt, String label) {
    final now = DateTime.now();

    if (updatedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      debugPrint('⚠️ Clock drift detected for $label');
    }
  }

  bool _isRemoteNewer(dynamic local, dynamic remote) {
    return SyncRemoteFreshnessPolicy.isRemoteNewer(
      localVersion: local.version as int,
      localUpdatedAt: local.updatedAt as DateTime,
      remoteVersion: remote.version as int,
      remoteUpdatedAt: remote.updatedAt as DateTime,
    );
  }

  SyncPushSnapshot _syncPushSnapshot(dynamic record) {
    return SyncPushSnapshot(
      id: record.id as int,
      version: record.version as int,
      updatedAt: record.updatedAt as DateTime,
    );
  }

  List<SyncPushSnapshot> _syncPushSnapshots(Iterable<dynamic> records) {
    return records.map(_syncPushSnapshot).toList(growable: false);
  }

  void _recordPushFailureDetail({
    required String entityType,
    required String entityId,
    required Object error,
    String? firestoreId,
  }) {
    final firebaseError = error is FirebaseException ? error : null;
    final message =
        firebaseError?.message?.trim().isNotEmpty == true
            ? firebaseError!.message!.trim()
            : error.toString();
    final isLikelyPermanent =
        firebaseError != null &&
        (firebaseError.code == 'permission-denied' ||
            firebaseError.code == 'failed-precondition' ||
            firebaseError.code == 'invalid-argument');
    final occurredAt = DateTime.now();
    final detail = SyncFailureDetail(
      entityType: entityType,
      entityId: entityId,
      message: message,
      errorCode: firebaseError?.code,
      firestoreId: firestoreId,
      isLikelyPermanent: isLikelyPermanent,
      occurredAt: occurredAt,
    );

    unawaited(_upsertSyncRejection(detail));

    if (lastFailureDetails.length >= _maxFailureDetails) {
      lastFailureDetailOverflowCount++;
      return;
    }

    lastFailureDetails.add(detail);
  }

  Future<void> _upsertSyncRejection(SyncFailureDetail detail) async {
    if (kIsWeb) {
      return;
    }
    final localIsar = Isar.getInstance();
    if (localIsar == null) {
      return;
    }

    try {
      await localIsar.writeTxn(() async {
        final existing =
            await localIsar.syncRejections
                .filter()
                .entityTypeEqualTo(detail.entityType)
                .and()
                .entityIdEqualTo(detail.entityId)
                .and()
                .isResolvedEqualTo(false)
                .findFirst();

        if (existing != null) {
          existing.markSeenAgain(
            message: detail.message,
            errorCode: detail.errorCode,
            firestoreId: detail.firestoreId,
            isLikelyPermanent: detail.isLikelyPermanent,
            at: detail.occurredAt,
          );
          await localIsar.syncRejections.put(existing);
          return;
        }

        final rejection =
            SyncRejection()
              ..entityType = detail.entityType
              ..entityId = detail.entityId
              ..firestoreId = detail.firestoreId
              ..errorCode = detail.errorCode
              ..message = detail.message
              ..firstSeenAt = detail.occurredAt
              ..lastSeenAt = detail.occurredAt
              ..attemptCount = 1
              ..isLikelyPermanent = detail.isLikelyPermanent
              ..isResolved = false;
        await localIsar.syncRejections.put(rejection);
      });
    } catch (e, st) {
      debugPrint(
        '⚠️ Failed to persist sync rejection for ${detail.shortLabel}: $e',
      );
      debugPrint('$st');
    }
  }

  void _recordPushFailuresForBatch({
    required String entityType,
    required Iterable<dynamic> records,
    required Object error,
  }) {
    for (final record in records) {
      _recordPushFailureDetail(
        entityType: entityType,
        entityId: _syncEntityId(record),
        firestoreId: _syncFirestoreId(record),
        error: error,
      );
    }
  }

  Future<List<T>> _recordsEligibleForAutomaticPush<T>({
    required String entityType,
    required List<T> records,
  }) async {
    if (records.isEmpty || kIsWeb) return records;

    final localIsar = Isar.getInstance();
    if (localIsar == null) return records;

    final candidateEntityIds = <String>{
      for (final record in records) _syncEntityId(record),
    };
    final candidateFirestoreIds = <String>{};
    for (final record in records) {
      final firestoreId = _syncFirestoreId(record);
      if (firestoreId != null) {
        candidateFirestoreIds.add(firestoreId);
      }
    }

    if (candidateEntityIds.isEmpty && candidateFirestoreIds.isEmpty) {
      return records;
    }

    List<SyncRejection> permanentRejections;
    try {
      permanentRejections =
          await localIsar.syncRejections
              .filter()
              .entityTypeEqualTo(entityType)
              .and()
              .isResolvedEqualTo(false)
              .and()
              .isLikelyPermanentEqualTo(true)
              .findAll();
    } catch (e, st) {
      debugPrint(
        '⚠️ Could not inspect sync rejection hold state for $entityType: $e',
      );
      debugPrint('$st');
      return records;
    }

    final rejectionsByEntityId = <String, SyncRejection>{};
    for (final rejection in permanentRejections) {
      if (candidateEntityIds.contains(rejection.entityId)) {
        rejectionsByEntityId[rejection.entityId] = rejection;
      }
      final firestoreId = rejection.firestoreId?.trim();
      if (firestoreId != null &&
          firestoreId.isNotEmpty &&
          candidateFirestoreIds.contains(firestoreId)) {
        rejectionsByEntityId[firestoreId] = rejection;
      }
    }

    if (rejectionsByEntityId.isEmpty) return records;

    final eligible = <T>[];
    for (final record in records) {
      final entityId = _syncEntityId(record);
      final firestoreId = _syncFirestoreId(record);
      final rejection =
          rejectionsByEntityId[entityId] ??
          (firestoreId == null ? null : rejectionsByEntityId[firestoreId]);

      if (rejection == null) {
        eligible.add(record);
        continue;
      }

      _recordAutomaticRetryHeld(
        entityType: entityType,
        entityId: entityId,
        firestoreId: firestoreId,
        rejection: rejection,
      );
    }

    return eligible;
  }

  void _recordAutomaticRetryHeld({
    required String entityType,
    required String entityId,
    required SyncRejection rejection,
    String? firestoreId,
  }) {
    lastFailureCount++;
    lastConflictKeys.add('$entityType:$entityId');

    if (lastFailureDetails.length >= _maxFailureDetails) {
      lastFailureDetailOverflowCount++;
      return;
    }

    lastFailureDetails.add(
      SyncFailureDetail(
        entityType: entityType,
        entityId: entityId,
        firestoreId: firestoreId ?? rejection.firestoreId,
        errorCode: rejection.errorCode ?? 'sync-rejection-held',
        message:
            'Automatic retry held because an unresolved likely permanent sync rejection exists. '
            'Review or resolve the rejection before retrying. Last rejection: ${rejection.displayMessage}',
        isLikelyPermanent: true,
        occurredAt: DateTime.now(),
      ),
    );

    debugPrint(
      '🛑 Held automatic sync retry for $entityType/$entityId due to unresolved permanent rejection: ${rejection.displayMessage}',
    );
  }

  String? _syncFirestoreId(dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return firestoreId.trim();
      }
    } catch (_) {
      // No firestoreId field or unreadable value.
    }
    return null;
  }

  String _syncEntityId(dynamic record) {
    final firestoreId = _syncFirestoreId(record);
    if (firestoreId != null) return firestoreId;

    try {
      return 'local:${record.id}';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _recordPushConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localSnapshot,
    required Map<String, dynamic> remoteSnapshot,
  }) async {
    lastConflictCount++;
    lastConflictKeys.add('$entityType:$entityId');

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final actorUid = firebaseUser?.uid;
    final actorName =
        firebaseUser?.displayName?.trim().isNotEmpty == true
            ? firebaseUser!.displayName!.trim()
            : firebaseUser?.email?.trim().isNotEmpty == true
            ? firebaseUser!.email!.trim()
            : 'Sync Engine';

    try {
      await _auditRepo.log(
        AuditEvent(
          entityType: entityType,
          entityId: entityId,
          action: AuditAction.update,
          performedByUid: actorUid ?? 'sync_engine',
          performedByName:
              actorUid == null ? 'Sync Engine' : 'Sync Engine ($actorName)',
          reasonNotes:
              'Sync conflict preserved during push. Local unsynced record was not pushed over newer remote data.',
          summary: 'Sync conflict preserved during push',
          severity: AuditSeverity.high,
          before: localSnapshot,
          after: remoteSnapshot,
        ),
        syncToRemote: actorUid != null,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Failed to audit push conflict for $entityType/$entityId: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATE GOVERNANCE (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncTemplateGovernance() async {
    await _syncTemplatePackages();
    await _syncTemplateVersions();
    await _syncTemplatePublishAudits();
  }

  Future<void> _syncTemplatePackages() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedPackages();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_package',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreTemplateGovernance
          .getPackagesByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <TemplatePackage>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_package',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template package ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template package ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template package ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          await _templateGovernanceRepo.applyTombstoneFromPackageRemote(remote);
          lastSuccessCount++;
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template_package',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertPackages(
              recordsToPush,
            );
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_package',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template package batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markPackagesSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  Future<void> _syncTemplateVersions() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedVersions();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_version',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreTemplateGovernance
          .getVersionsByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <TemplateVersion>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_version',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template version ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template version ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template version ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          await _templateGovernanceRepo.applyTombstoneFromVersionRemote(remote);
          lastSuccessCount++;
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template_version',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertVersions(
              recordsToPush,
            );
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_version',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template version batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markVersionsSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  Future<void> _syncTemplatePublishAudits() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedAudits();
    if (unsynced.isEmpty) {
      return;
    }

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_publish_audit',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();
      final remoteList = await _firestoreTemplateGovernance
          .getAuditsByFirestoreIds(firestoreIds);
      final remoteIds =
          remoteList.map((e) => e.firestoreId).whereType<String>().toSet();

      final recordsToPush = <TemplatePublishAudit>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_publish_audit',
            entityId: 'local:${record.id}',
            error:
                'Missing firestoreId for template publish audit ${record.id}',
          );
          debugPrint(
            '❌ Missing firestoreId for template publish audit ${record.id}',
          );
          continue;
        }

        if (remoteIds.contains(record.firestoreId)) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertAudits(recordsToPush);
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_publish_audit',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template publish audit batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markAuditsSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TICKETS (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncTickets() async {
    final unsynced = await _maintenanceRepo.getUnsyncedTickets();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'maintenance_ticket',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreMaintenance.getTicketsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <MaintenanceRecord>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'maintenance_ticket',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for ticket ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for ticket ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'ticket ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _maintenanceRepo.applyTombstoneFromMaintenanceRemote(remote);
            lastSuccessCount++;
            debugPrint('📥 Applied remote tombstone for ticket ${record.id}');
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for ticket ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'ticket',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local ticket ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreMaintenance.batchUpsertTickets(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'maintenance_ticket',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Ticket batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _maintenanceRepo.markTicketsSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TEMPLATES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncTemplates() async {
    final unsynced = await _plannedRepo.getUnsyncedTemplates();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_template',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestorePlanned.getTemplatesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobTemplate>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_template',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _plannedRepo.applyTombstoneFromTemplateRemote(remote);
            lastSuccessCount++;
            debugPrint('📥 Applied remote tombstone for template ${record.id}');
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for template ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local template ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestorePlanned.batchUpsertTemplates(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'job_template',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _plannedRepo.markTemplatesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXECUTIONS (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncExecutions({bool skipCompletedClosures = false}) async {
    final unsynced = await _plannedRepo.getUnsyncedExecutions();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_execution',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestorePlanned.getExecutionsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobExecution>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_execution',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for execution ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for execution ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'execution ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          if (_shouldRebaseRejectedExecutionTombstone(record, remote)) {
            await _recordPushConflict(
              entityType: 'job_execution',
              entityId: record.firestoreId!,
              localSnapshot: record.toMap(),
              remoteSnapshot: remote!.toMap(),
            );

            await _plannedRepo.forceRebaseExecutionFromRemote(
              remote,
              reason:
                  'Rules reject local job-execution tombstones. '
                  'The local snapshot was preserved in audit before rebasing.',
            );

            lastSuccessCount++;
            debugPrint(
              '🛡️ Rebased local job execution tombstone from remote: '
              '${record.firestoreId} (${_shortText(record.templateName ?? record.templateFirestoreId)})',
            );
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _plannedRepo.applyTombstoneFromExecutionRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for execution ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for execution ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (record.isCompleted) {
          if (skipCompletedClosures) {
            continue;
          }

          final serverCompleted = await _syncCompletedExecutionThroughServer(
            record,
            remote,
          );
          if (serverCompleted) {
            lastSuccessCount++;
          }
          // Never fall back to direct Firestore batch upsert for completed
          // executions. Firestore rules now deny client completion so the
          // Cloud Function remains the single completion authority.
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'execution',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local execution ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestorePlanned.batchUpsertExecutions(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Execution batch sync failed; splitting batch for diagnostics: $e',
          );
          debugPrintStack(stackTrace: stackTrace);

          for (final record in recordsToPush) {
            try {
              await _retry(() async {
                await _firestorePlanned.batchUpsertExecutions([record]);
              });

              lastSuccessCount++;
              skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
              debugPrint(
                '✅ Execution synced after batch split: '
                '${record.firestoreId ?? record.id.toString()} '
                '(${_shortText(record.templateName ?? record.templateFirestoreId)})',
              );
            } catch (singleError, singleStackTrace) {
              final remote =
                  record.firestoreId == null
                      ? null
                      : remoteMap[record.firestoreId];

              if (_shouldRebaseRejectedExecutionTombstone(record, remote)) {
                await _recordPushConflict(
                  entityType: 'job_execution',
                  entityId: record.firestoreId!,
                  localSnapshot: record.toMap(),
                  remoteSnapshot: remote!.toMap(),
                );

                await _plannedRepo.forceRebaseExecutionFromRemote(
                  remote,
                  reason:
                      'Rules rejected a dirty local job-execution tombstone. '
                      'The local snapshot was preserved in audit before rebasing.',
                );

                lastSuccessCount++;
                debugPrint(
                  '🛡️ Rebased rejected job execution tombstone from remote: '
                  '${record.firestoreId} (${_shortText(record.templateName ?? record.templateFirestoreId)})',
                );
                continue;
              }

              lastFailureCount++;
              _recordPushFailureDetail(
                entityType: 'job_execution',
                entityId: _syncEntityId(record),
                error: singleError,
              );
              debugPrint(
                '❌ Execution sync rejected after single-record retry:\n'
                '${_describeExecutionForSync(record, remote)}\n'
                'Error: $singleError',
              );
              debugPrintStack(stackTrace: singleStackTrace);
            }
          }
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _plannedRepo.markExecutionsSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  Future<void> _syncCompletedExecutionClosures() async {
    final unsynced = await _plannedRepo.getUnsyncedExecutions();
    final completed =
        unsynced
            .where(
              (execution) =>
                  execution.isCompleted &&
                  !execution.isDeleted &&
                  execution.firestoreId != null &&
                  execution.firestoreId!.trim().isNotEmpty,
            )
            .toList();

    if (completed.isEmpty) {
      return;
    }

    for (var i = 0; i < completed.length; i += 100) {
      final batchRecords = completed.sublist(
        i,
        i + 100 > completed.length ? completed.length : i + 100,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_execution',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((execution) => execution.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestorePlanned.getExecutionsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {
        for (final remote in remoteList) remote.firestoreId: remote,
      };

      for (final record in activeBatchRecords) {
        final accepted = await _syncCompletedExecutionThroughServer(
          record,
          remoteMap[record.firestoreId],
        );
        if (accepted) {
          lastSuccessCount++;
        }
      }
    }
  }

  Future<bool> _syncCompletedExecutionThroughServer(
    JobExecution local,
    JobExecution? remote,
  ) async {
    final firestoreId = local.firestoreId;
    if (firestoreId == null || firestoreId.trim().isEmpty) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: 'local:${local.id}',
        error:
            'Completed local execution has no firestoreId; cannot route through server closure function.',
      );
      return false;
    }

    if (remote == null) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Remote execution is missing; server-side completion cannot be validated.',
      );
      return false;
    }

    if (remote.isDeleted) {
      try {
        await _plannedRepo.applyTombstoneFromExecutionRemote(remote);
        debugPrint(
          '📥 Applied remote tombstone for completed execution ${local.id}',
        );
        return true;
      } catch (error, stackTrace) {
        lastFailureCount++;
        _recordPushFailureDetail(
          entityType: 'job_execution',
          entityId: _syncEntityId(local),
          firestoreId: firestoreId,
          error: error,
        );
        debugPrint('❌ Failed applying remote execution tombstone: $error');
        debugPrintStack(stackTrace: stackTrace);
        return false;
      }
    }

    if (remote.isCompleted) {
      await _recordPushConflict(
        entityType: 'execution',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote.toAuditMap(),
      );
      await _plannedRepo.forceRebaseExecutionFromRemote(
        remote,
        reason:
            'Remote job execution is already server-completed. '
            'Local dirty completion snapshot was preserved in audit before rebasing.',
      );
      debugPrint(
        '🛡️ Rebased local completed execution from canonical server completion: '
        '$firestoreId',
      );
      return true;
    }

    if (_isRemoteNewer(local, remote)) {
      await _recordPushConflict(
        entityType: 'execution',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote.toAuditMap(),
      );
      lastFailureCount++;
      return false;
    }

    final completedByUid = _cleanText(local.completedByUid);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (completedByUid == null || currentUid != completedByUid) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Server-side completion requires the signed-in user to match completedByUid.',
      );
      return false;
    }

    final localModules = await _jobModuleRepo.getModulesForJob(
      jobExecutionFirestoreId: firestoreId,
    );
    final unsyncedModules =
        localModules.where((module) => !module.isSynced).toList();
    if (unsyncedModules.isNotEmpty) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Cannot server-complete job before ${unsyncedModules.length} dirty module(s) are synced.',
      );
      return false;
    }

    try {
      final completed = await _serverCompletion.completeExecution(
        executionFirestoreId: firestoreId,
        remarks: local.remarks,
        teamsInvolved: local.teamsInvolved,
        responses: local.responses,
        actions: local.actions,
        expectedCompletionVersion: local.version,
      );

      await _plannedRepo.forceRebaseExecutionFromRemote(
        completed,
        reason:
            'Local completed execution was accepted by server-side closure function.',
      );

      debugPrint(
        '✅ Server-side planned-job completion accepted during sync: '
        '$firestoreId',
      );
      return true;
    } catch (error, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: firestoreId,
        error: error,
      );
      debugPrint(
        '❌ Server-side planned-job completion failed during sync for '
        '$firestoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  bool _shouldRebaseRejectedExecutionTombstone(
    JobExecution local,
    JobExecution? remote,
  ) {
    if (remote == null) return false;
    if (!local.isDeleted || remote.isDeleted) return false;

    // Identity fields pinned by Firestore rules must match exactly.
    if (local.templateFirestoreId != remote.templateFirestoreId) return false;
    if (local.assetType != remote.assetType) return false;
    if (local.assetNumber != remote.assetNumber) return false;

    // Do not silently discard actual dossier content. These tombstones are
    // safe to rebase only when no local checklist responses/actions are waiting
    // to be recovered. If this guard fails, diagnostics stay loud.
    if (local.responses.isNotEmpty) return false;
    if (local.actions.isNotEmpty) return false;

    // Completion state must already agree with remote. The timestamp/version may
    // differ due to historical double-completion/local tombstone drift, but a
    // true local completion over an open remote job must never be rebased away.
    if (local.isCompleted != remote.isCompleted) return false;
    if (_cleanText(local.completedByUid) != _cleanText(remote.completedByUid)) {
      return false;
    }

    // Preserve potentially meaningful local business fields by refusing the
    // automatic rebase when they differ. The diagnostic block will then show the
    // exact rejected record for manual handling.
    if (_cleanText(local.remarks) != _cleanText(remote.remarks)) return false;
    if (!_sameStringList(local.teamsInvolved, remote.teamsInvolved)) {
      return false;
    }
    if (local.chargeNoAtEvent != remote.chargeNoAtEvent) return false;
    if (_cleanText(local.metadataJson) != _cleanText(remote.metadataJson)) {
      return false;
    }

    return true;
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _sameStringList(List<String> a, List<String> b) {
    final left = a.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final right = b.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  String _describeExecutionForSync(JobExecution local, JobExecution? remote) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    final buffer =
        StringBuffer()
          ..writeln('  currentAuthUid: $currentUid')
          ..writeln('  firestoreId: ${local.firestoreId ?? 'null'}')
          ..writeln('  localId: ${local.id}')
          ..writeln(
            '  template: ${_shortText(local.templateName ?? local.templateFirestoreId)}',
          )
          ..writeln(
            '  local asset/version/isCompleted/isDeleted/isSynced: '
            '${local.assetType.name}/${local.assetNumber}/${local.version}/'
            '${local.isCompleted}/${local.isDeleted}/${local.isSynced}',
          )
          ..writeln(
            '  remote asset/version/isCompleted/isDeleted: '
            '${remote?.assetType.name ?? 'missing'}/'
            '${remote?.assetNumber.toString() ?? 'missing'}/'
            '${remote?.version.toString() ?? 'missing'}/'
            '${remote?.isCompleted.toString() ?? 'missing'}/'
            '${remote?.isDeleted.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local completedBy/completedAt: '
            '${_uid(local.completedByUid)}/${_date(local.completedAt)}',
          )
          ..writeln(
            '  remote completedBy/completedAt: '
            '${_uid(remote?.completedByUid)}/${_date(remote?.completedAt)}',
          )
          ..writeln('  local updatedAt: ${_date(local.updatedAt)}')
          ..writeln('  remote updatedAt: ${_date(remote?.updatedAt)}')
          ..writeln(
            '  local response/action counts: '
            '${local.responses.length}/${local.actions.length}',
          )
          ..writeln(
            '  remote response/action counts: '
            '${remote?.responses.length.toString() ?? 'missing'}/'
            '${remote?.actions.length.toString() ?? 'missing'}',
          )
          ..writeln(
            '  pinned-field comparison: ${_executionPinnedFieldDiff(local, remote)}',
          )
          ..writeln(
            '  completion-field comparison: ${_executionCompletionFieldDiff(local, remote)}',
          );

    return buffer.toString().trimRight();
  }

  String _executionPinnedFieldDiff(JobExecution local, JobExecution? remote) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.templateFirestoreId != remote.templateFirestoreId) {
      diffs.add('templateFirestoreId');
    }
    if (local.assetType != remote.assetType) diffs.add('assetType');
    if (local.assetNumber != remote.assetNumber) diffs.add('assetNumber');
    if (local.isDeleted != remote.isDeleted) diffs.add('isDeleted');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _executionCompletionFieldDiff(
    JobExecution local,
    JobExecution? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.isCompleted != remote.isCompleted) diffs.add('isCompleted');
    if (local.completedByUid != remote.completedByUid) {
      diffs.add('completedByUid');
    }
    if (local.completedByName != remote.completedByName) {
      diffs.add('completedByName');
    }
    if (!_sameInstant(local.completedAt, remote.completedAt)) {
      diffs.add('completedAt');
    }
    if (local.version != remote.version) diffs.add('version');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  // ─────────────────────────────────────────────────────────────
  // JOB DIARY ENTRIES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncJobDiaryEntries() async {
    final unsynced = await _jobDiaryRepo.getUnsyncedEntries();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_diary_entry',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreJobDiary.getEntriesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobDiaryEntry>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_diary_entry',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for job diary entry ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for job diary entry ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'job diary entry ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _jobDiaryRepo.applyTombstoneFromRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for job diary entry ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for job diary entry ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'planned_job_diary_entry',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local job diary entry ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreJobDiary.batchUpsertEntries(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'job_diary_entry',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Job diary entry batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _jobDiaryRepo.markEntriesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // JOB MODULES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncJobModules() async {
    final unsynced = await _jobModuleRepo.getUnsyncedModules();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_module',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreJobModule.getModulesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobModuleInstance>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_module',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for job module ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for job module ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'job module ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _jobModuleRepo.applyTombstoneFromRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for job module ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for job module ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'planned_job_module',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local job module ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreJobModule.batchUpsertModules(recordsToPush);
          });

          lastSuccessCount += recordsToPush.length;
          snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Job module batch sync failed; splitting batch for diagnostics: $e',
          );
          debugPrintStack(stackTrace: stackTrace);

          for (final record in recordsToPush) {
            try {
              await _retry(() async {
                await _firestoreJobModule.batchUpsertModules([record]);
              });

              lastSuccessCount++;
              snapshotsToMark.add(_syncPushSnapshot(record));
              debugPrint(
                '✅ Job module synced after batch split: '
                '${record.firestoreId ?? record.id.toString()} '
                '(${_shortText(record.moduleTitle)})',
              );
            } catch (singleError, singleStackTrace) {
              final remote =
                  record.firestoreId == null
                      ? null
                      : remoteMap[record.firestoreId];

              if (_shouldRebaseRejectedTerminalJobModule(record, remote)) {
                await _recordPushConflict(
                  entityType: 'planned_job_module',
                  entityId: record.firestoreId!,
                  localSnapshot: record.toMap(),
                  remoteSnapshot: remote!.toMap(),
                );

                await _jobModuleRepo.forceRebaseModuleFromRemote(
                  remote,
                  reason:
                      'Rules rejected a dirty terminal-state module push. '
                      'The local snapshot was preserved in audit before rebasing.',
                );

                lastSuccessCount++;
                debugPrint(
                  '🛡️ Rebased rejected terminal job module from remote: '
                  '${record.firestoreId} (${_shortText(record.moduleTitle)})',
                );
                continue;
              }

              lastFailureCount++;
              _recordPushFailureDetail(
                entityType: 'job_module',
                entityId: _syncEntityId(record),
                error: singleError,
              );
              debugPrint(
                '❌ Job module sync rejected after single-record retry:\n'
                '${_describeJobModuleForSync(record, remote)}\n'
                'Error: $singleError',
              );
              debugPrintStack(stackTrace: singleStackTrace);
            }
          }
        }
      }

      if (snapshotsToMark.isNotEmpty) {
        await _jobModuleRepo.markModulesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  bool _shouldRebaseRejectedTerminalJobModule(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null || local.firestoreId == null) return false;
    if (local.firestoreId != remote.firestoreId) return false;
    if (local.isDeleted || remote.isDeleted) return false;
    if (local.status != remote.status) return false;

    final isTerminal =
        local.status == JobModuleStatus.submitted ||
        local.status == JobModuleStatus.accepted ||
        local.status == JobModuleStatus.notApplicable;
    if (!isTerminal) return false;

    if (_jobModulePinnedFieldDiff(local, remote) != 'none') return false;

    // Once a module is in a terminal state on the server, Firestore rules
    // correctly refuse "submitted -> submitted" edits. A dirty local copy with
    // stale reopen/submission metadata can therefore never be pushed. Preserve
    // the local snapshot in audit and rebase to the server's canonical module.
    return _jobModuleLifecycleDiff(local, remote) != 'none' ||
        local.responsesJson != remote.responsesJson ||
        local.actionsJson != remote.actionsJson ||
        local.pendingIssue != remote.pendingIssue ||
        local.requiresFollowUp != remote.requiresFollowUp ||
        local.version != remote.version;
  }

  String _describeJobModuleForSync(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    final buffer =
        StringBuffer()
          ..writeln('  currentAuthUid: $currentUid')
          ..writeln('  firestoreId: ${local.firestoreId ?? 'null'}')
          ..writeln('  localId: ${local.id}')
          ..writeln('  title: ${_shortText(local.moduleTitle, max: 120)}')
          ..writeln(
            '  local status/discipline/version/isSynced/isDeleted: '
            '${local.status.name}/${local.discipline.name}/${local.version}/'
            '${local.isSynced}/${local.isDeleted}',
          )
          ..writeln(
            '  remote status/discipline/version/isDeleted: '
            '${remote?.status.name ?? 'missing'}/'
            '${remote?.discipline.name ?? 'missing'}/'
            '${remote?.version.toString() ?? 'missing'}/'
            '${remote?.isDeleted.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local createdBy/updatedBy/submittedBy/acceptedBy/reopenedBy/notApplicableBy/deletedBy: '
            '${_uid(local.createdByUid)}/${_uid(local.updatedByUid)}/'
            '${_uid(local.submittedByUid)}/${_uid(local.acceptedByUid)}/'
            '${_uid(local.reopenedByUid)}/${_uid(local.notApplicableByUid)}/'
            '${_uid(local.deletedByUid)}',
          )
          ..writeln(
            '  remote createdBy/updatedBy/submittedBy/acceptedBy/reopenedBy/notApplicableBy/deletedBy: '
            '${_uid(remote?.createdByUid)}/${_uid(remote?.updatedByUid)}/'
            '${_uid(remote?.submittedByUid)}/${_uid(remote?.acceptedByUid)}/'
            '${_uid(remote?.reopenedByUid)}/${_uid(remote?.notApplicableByUid)}/'
            '${_uid(remote?.deletedByUid)}',
          )
          ..writeln(
            '  local assetType/assetNumber: '
            '${local.assetType.name}/${local.assetNumber}',
          )
          ..writeln(
            '  remote assetType/assetNumber: '
            '${remote?.assetType.name ?? 'missing'}/'
            '${remote?.assetNumber.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local createdAt/updatedAt: '
            '${_date(local.createdAt)}/${_date(local.updatedAt)}',
          )
          ..writeln(
            '  remote createdAt/updatedAt: '
            '${_date(remote?.createdAt)}/${_date(remote?.updatedAt)}',
          )
          ..writeln(
            '  local response/action counts: '
            '${local.responses.length}/${local.actions.length}',
          )
          ..writeln(
            '  remote response/action counts: '
            '${remote?.responses.length.toString() ?? 'missing'}/'
            '${remote?.actions.length.toString() ?? 'missing'}',
          )
          ..writeln(
            '  payload comparison: ${_jobModulePayloadDiff(local, remote)}',
          )
          ..writeln(
            '  pinned-field comparison: ${_jobModulePinnedFieldDiff(local, remote)}',
          )
          ..writeln(
            '  lifecycle-field comparison: ${_jobModuleLifecycleDiff(local, remote)}',
          );

    return buffer.toString().trimRight();
  }

  String _jobModulePinnedFieldDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.createdByUid != remote.createdByUid) diffs.add('createdByUid');
    if (!_sameInstant(local.createdAt, remote.createdAt)) {
      diffs.add('createdAt');
    }
    if (local.moduleSnapshotJson != remote.moduleSnapshotJson) {
      diffs.add('moduleSnapshotJson');
    }
    if (local.fieldDefinitionsJson != remote.fieldDefinitionsJson) {
      diffs.add('fieldDefinitionsJson');
    }
    if (local.assetType != remote.assetType) diffs.add('assetType');
    if (local.assetNumber != remote.assetNumber) diffs.add('assetNumber');
    if (local.discipline != remote.discipline) diffs.add('discipline');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _jobModulePayloadDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.responsesJson != remote.responsesJson) diffs.add('responsesJson');
    if (local.actionsJson != remote.actionsJson) diffs.add('actionsJson');
    if (local.draftNote != remote.draftNote) diffs.add('draftNote');
    if (local.pendingIssue != remote.pendingIssue) diffs.add('pendingIssue');
    if (local.requiresFollowUp != remote.requiresFollowUp) {
      diffs.add('requiresFollowUp');
    }

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _jobModuleLifecycleDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.status != remote.status) diffs.add('status');
    if (local.isDeleted != remote.isDeleted) diffs.add('isDeleted');
    if (local.submittedByUid != remote.submittedByUid) {
      diffs.add('submittedByUid');
    }
    if (local.submittedByName != remote.submittedByName) {
      diffs.add('submittedByName');
    }
    if (!_sameInstant(local.submittedAt, remote.submittedAt)) {
      diffs.add('submittedAt');
    }
    if (local.submissionNote != remote.submissionNote) {
      diffs.add('submissionNote');
    }
    if (local.acceptedByUid != remote.acceptedByUid) diffs.add('acceptedByUid');
    if (local.acceptedByName != remote.acceptedByName) {
      diffs.add('acceptedByName');
    }
    if (!_sameInstant(local.acceptedAt, remote.acceptedAt)) {
      diffs.add('acceptedAt');
    }
    if (local.acceptanceNote != remote.acceptanceNote) {
      diffs.add('acceptanceNote');
    }
    if (local.reopenedByUid != remote.reopenedByUid) diffs.add('reopenedByUid');
    if (local.reopenedByName != remote.reopenedByName) {
      diffs.add('reopenedByName');
    }
    if (!_sameInstant(local.reopenedAt, remote.reopenedAt)) {
      diffs.add('reopenedAt');
    }
    if (local.reopenReason != remote.reopenReason) diffs.add('reopenReason');
    if (local.notApplicableByUid != remote.notApplicableByUid) {
      diffs.add('notApplicableByUid');
    }
    if (local.notApplicableByName != remote.notApplicableByName) {
      diffs.add('notApplicableByName');
    }
    if (!_sameInstant(local.notApplicableAt, remote.notApplicableAt)) {
      diffs.add('notApplicableAt');
    }
    if (local.notApplicableReason != remote.notApplicableReason) {
      diffs.add('notApplicableReason');
    }
    if (local.deletedByUid != remote.deletedByUid) diffs.add('deletedByUid');
    if (local.deletedByName != remote.deletedByName) diffs.add('deletedByName');
    if (!_sameInstant(local.deletedAt, remote.deletedAt)) {
      diffs.add('deletedAt');
    }
    if (local.deleteReason != remote.deleteReason) diffs.add('deleteReason');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  bool _sameInstant(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  String _uid(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'null';
    return trimmed;
  }

  String _date(DateTime? value) => value?.toIso8601String() ?? 'null';

  String _shortText(String value, {int max = 80}) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max - 1)}…';
  }

  // ─────────────────────────────────────────────────────────────
  // DIRECTIVES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncDirectives() async {
    final unsynced = await _directiveRepo.getUnsyncedDirectives();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'directive',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreDirective.getDirectivesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <OperationalDirective>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'directive',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for directive ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for directive ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'directive ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _directiveRepo.applyTombstoneFromDirectiveRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for directive ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for directive ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'directive',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local directive ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreDirective.batchUpsertDirectives(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'directive',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Directive batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _directiveRepo.markDirectivesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ABNORMALITY TYPES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncAbnormalityTypes() async {
    final unsynced = await _abnormalityRepo.getUnsyncedTypes();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'abnormality_type',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreAbnormality.getTypesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <AbnormalityType>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'abnormality_type',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for abnormality type ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for abnormality type ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'abnormality type ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _abnormalityRepo.applyTombstoneFromTypeRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for abnormality type ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for abnormality type ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'abnormality_type',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local abnormality type ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreAbnormality.batchUpsertTypes(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'abnormality_type',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Abnormality type batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markTypesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CHARGE ABNORMALITIES (BATCHED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _syncChargeAbnormalities() async {
    final unsynced = await _abnormalityRepo.getUnsyncedAbnormalities();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'charge_abnormality',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreAbnormality
          .getAbnormalitiesByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <ChargeAbnormality>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'charge_abnormality',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for charge abnormality ${record.id}',
          );
          debugPrint(
            '❌ Missing firestoreId for charge abnormality ${record.id}',
          );
          continue;
        }

        _checkClockDrift(record.updatedAt, 'charge abnormality ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _abnormalityRepo.applyTombstoneFromAbnormalityRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for charge abnormality ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for charge abnormality ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'charge_abnormality',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local charge abnormality ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreAbnormality.batchUpsertAbnormalities(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'charge_abnormality',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Charge abnormality batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markAbnormalitiesSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  Future<bool> _isKnowledgeBaseBatchHeldByPermanentRejection() async {
    if (kIsWeb) return false;
    final localIsar = Isar.getInstance();
    if (localIsar == null) return false;

    try {
      final rejection =
          await localIsar.syncRejections
              .filter()
              .entityTypeEqualTo('baf_knowledge_row')
              .and()
              .entityIdEqualTo('knowledge_base_batch')
              .and()
              .isResolvedEqualTo(false)
              .and()
              .isLikelyPermanentEqualTo(true)
              .findFirst();

      if (rejection == null) return false;

      _recordAutomaticRetryHeld(
        entityType: 'baf_knowledge_row',
        entityId: 'knowledge_base_batch',
        rejection: rejection,
      );
      return true;
    } catch (e, st) {
      debugPrint(
        '⚠️ Could not inspect knowledge-base sync rejection hold state: $e',
      );
      debugPrint('$st');
      return false;
    }
  }

  Future<void> _syncKnowledgeBase() async {
    if (await _isKnowledgeBaseBatchHeldByPermanentRejection()) {
      return;
    }

    try {
      final pushed = await _knowledgeRepo.syncUnsyncedToCloud();
      lastSuccessCount += pushed;
    } catch (e, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'baf_knowledge_row',
        entityId: 'knowledge_base_batch',
        error: e,
      );
      debugPrint('❌ Knowledge Base sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    maintenanceRepo: ref.read(maintenanceRepositoryProvider),
    firestoreMaintenance: ref.read(firestoreMaintenanceRepo),
    plannedRepo: ref.read(plannedRepositoryProvider),
    firestorePlanned: ref.read(firestorePlannedRepo),
    serverCompletion: ref.read(plannedJobServerCompletionServiceProvider),
    jobDiaryRepo: ref.read(jobDiaryRepositoryProvider),
    firestoreJobDiary: ref.read(firestoreJobDiaryRepoProvider),
    jobModuleRepo: ref.read(jobModuleRepositoryProvider),
    firestoreJobModule: ref.read(firestoreJobModuleRepoProvider),
    templateGovernanceRepo: ref.read(templateGovernanceRepositoryProvider),
    firestoreTemplateGovernance: ref.read(firestoreTemplateGovernanceRepo),
    directiveRepo: ref.read(directiveRepositoryProvider),
    firestoreDirective: ref.read(firestoreDirectiveRepo),
    abnormalityRepo: ref.read(abnormalityRepositoryProvider),
    firestoreAbnormality: ref.read(firestoreAbnormalityRepoProvider),
    knowledgeRepo: ref.read(bafKnowledgeRepositoryProvider),
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final syncPendingCountsProvider = FutureProvider.autoDispose<SyncPendingCounts>(
  (ref) {
    final status = ref.watch(syncStatusProvider);
    // Recompute after state changes from syncing → success/failed/idle.
    status.name;
    return ref.read(syncServiceProvider).countPendingLocalWrites();
  },
);
