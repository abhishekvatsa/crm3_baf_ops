// FILE: lib/core/services/global_pull_service.dart

import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/providers/maintenance_provider.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import '../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
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
import 'remote_tombstone_apply_result.dart';
import 'sync_remote_freshness_policy.dart';
import 'app_logger.dart';

// ─────────────────────────────────────────────────────────────
// GLOBAL PULL SERVICE (PAGINATED & WEB-SAFE)
// Depends on abstract repositories – prevents Isar init crashes on Web.
// ─────────────────────────────────────────────────────────────

class GlobalPullService {
  final MaintenanceRepository _maintenanceRepo;
  final FirestoreMaintenanceRepository _firestoreMaintenance;

  final PlannedMaintenanceRepository _plannedRepo;
  final FirestorePlannedRepository _firestorePlanned;

  final JobDiaryRepository _jobDiaryRepo;
  final JobDiaryRepository _firestoreJobDiary;

  final JobModuleRepository _jobModuleRepo;
  final JobModuleRepository _firestoreJobModule;

  final TemplateGovernanceRepository _templateGovernanceRepo;
  final FirestoreTemplateGovernanceRepository _firestoreTemplateGovernance;

  final DirectiveRepository _directiveRepo;
  final FirestoreDirectiveRepository _firestoreDirective;

  final AbnormalityRepository _abnormalityRepo;
  final FirestoreAbnormalityRepository _firestoreAbnormality;

  final BafKnowledgeRepository _knowledgeRepo;

  final AuditRepository _auditRepo;

  bool _isPulling = false;
  bool _hadRecordProcessingError = false;
  DateTime? _maxFetchedRemoteUpdatedAt;

  int lastInserted = 0;
  int lastUpdated = 0;
  int lastSkipped = 0;
  int lastDeleted = 0;
  int lastConflicted = 0;
  final Set<String> lastConflictKeys = <String>{};

  static const int _pageSize = 500;
  static const Duration _pullTokenSafetyMargin = Duration(minutes: 5);

  GlobalPullService(
    this._maintenanceRepo,
    this._firestoreMaintenance,
    this._plannedRepo,
    this._firestorePlanned,
    this._jobDiaryRepo,
    this._firestoreJobDiary,
    this._jobModuleRepo,
    this._firestoreJobModule,
    this._templateGovernanceRepo,
    this._firestoreTemplateGovernance,
    this._directiveRepo,
    this._firestoreDirective,
    this._abnormalityRepo,
    this._firestoreAbnormality,
    this._knowledgeRepo,
    this._auditRepo,
  );

  // ─────────────────────────────────────────────────────────────
  // ENTRY POINT
  // ─────────────────────────────────────────────────────────────

  Future<void> pullAndReconcile() async {
    if (_isPulling) return;

    _isPulling = true;

    lastInserted = 0;
    lastUpdated = 0;
    lastSkipped = 0;
    lastDeleted = 0;
    lastConflicted = 0;
    lastConflictKeys.clear();
    _hadRecordProcessingError = false;
    _maxFetchedRemoteUpdatedAt = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_global_pull');
      DateTime? lastSync;

      if (lastSyncStr != null) {
        lastSync = DateTime.tryParse(lastSyncStr);
      }

      await _pullKnowledgeBase(lastSync);
      await _pullMaintenance(lastSync);
      await _pullPlanned(lastSync);
      await _pullDirectives(lastSync);

      // Master data first, then event records.
      await _pullAbnormalities(lastSync);

      if (_hadRecordProcessingError) {
        throw Exception(
          'Global pull completed with record processing errors; not advancing token.',
        );
      }

      // Only advance the token if ALL domains successfully completed without throwing.
      // Use the freshest remote updatedAt we actually fetched, not the tablet's
      // local clock. Skewed unmanaged Android tablets must not be able to move
      // the global pull watermark into the future and skip server rows.
      final nextSyncToken = _nextGlobalPullToken(previousToken: lastSync);
      if (nextSyncToken != null) {
        await prefs.setString(
          'last_global_pull',
          nextSyncToken.toIso8601String(),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Global pull failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(
        AppLogger.recordNonFatalError(
          e,
          stackTrace,
          reason: 'global_delta_sync_failed',
          context: const {'app_area': 'sync', 'sync_phase': 'global_pull'},
        ),
      );

      rethrow;
    } finally {
      _isPulling = false;

      debugPrint(
        '📥 GLOBAL PULL → Inserted: $lastInserted, Updated: $lastUpdated, Deleted: $lastDeleted, Conflicted: $lastConflicted, Skipped: $lastSkipped',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // WATERMARK HELPERS
  // ─────────────────────────────────────────────────────────────

  DateTime? _nextGlobalPullToken({DateTime? previousToken}) {
    final maxFetched = _maxFetchedRemoteUpdatedAt;
    if (maxFetched == null) return previousToken;

    final candidate = maxFetched.subtract(_pullTokenSafetyMargin);
    if (previousToken != null && candidate.isBefore(previousToken)) {
      return previousToken;
    }
    return candidate;
  }

  void _observeFetchedRemoteRecords(Iterable<dynamic> records) {
    for (final record in records) {
      _observeFetchedRemoteUpdatedAt(_readUpdatedAt(record));
    }
  }

  void _observeFetchedRemoteUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return;
    final current = _maxFetchedRemoteUpdatedAt;
    if (current == null || updatedAt.isAfter(current)) {
      _maxFetchedRemoteUpdatedAt = updatedAt;
    }
  }

  DateTime? _readUpdatedAt(dynamic record) {
    try {
      final value = record.updatedAt;
      if (value is DateTime) return value;
    } catch (_) {
      // Best-effort watermark tracking; malformed records are handled by the
      // entity-specific processing paths below.
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // CONFLICT HELPERS
  // ─────────────────────────────────────────────────────────────

  // Sync-winner policy note:
  //
  // Remote *updates* are evaluated with a version-primary rule, using
  // updatedAt only as the tie-breaker when versions match. This mirrors the
  // push path's _isRemoteNewer contract and prevents a lower-version remote
  // edit from displacing a newer local version merely because clocks differ.
  //
  // Dirty local rows are still treated as loss-sensitive evidence. When a
  // local row is unsynced and the remote row is strictly newer by the
  // version-primary rule, this pull service preserves the local row, records a
  // pull conflict via _logPullConflict(), and emits a high-severity audit event
  // through _logConflictAudit(). When the remote row is not strictly newer, the
  // local dirty row is also preserved and counted as skipped.
  //
  // Clean local rows use an additional timestamp guard: if the local row is
  // already synced but its updatedAt is after the fetched remote row, the remote
  // row is skipped. This is deliberate clock-skew protection for unmanaged
  // tablets and stale delta windows; it is not the dirty-row conflict path.
  //
  // Remote *tombstones* are more destructive than normal updates, so tombstone
  // application remains delegated to repository-level applyTombstoneFrom*Remote
  // helpers. Those helpers preserve fresher unsynced local evidence and return
  // RemoteTombstoneApplyResult so this service can count/audit the conflict.
  // Do not collapse tombstone handling into the normal update-winner branch.

  String _conflictKey(String entityLabel, dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return '$entityLabel:$firestoreId';
      }
    } catch (_) {
      // Fall through to local id.
    }

    try {
      return '$entityLabel:local:${record.id}';
    } catch (_) {
      return '$entityLabel:unknown';
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

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.name;
    if (value is Iterable) return value.map((v) => _jsonSafeValue(v)).toList();
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _jsonSafeValue(mapValue)),
      );
    }
    return value.toString();
  }

  Map<String, dynamic> _safeAuditMap(dynamic record) {
    try {
      final dynamic raw = record.toAuditMap();
      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry(key.toString(), _jsonSafeValue(value)),
        );
      }
    } catch (_) {
      // Fall back to a small sync metadata snapshot.
    }

    dynamic readField(String name) {
      try {
        switch (name) {
          case 'firestoreId':
            return record.firestoreId;
          case 'id':
            return record.id;
          case 'version':
            return record.version;
          case 'updatedAt':
            return record.updatedAt;
          case 'isDeleted':
            return record.isDeleted;
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    return {
      'firestoreId': _jsonSafeValue(readField('firestoreId')),
      'localId': _jsonSafeValue(readField('id')),
      'version': _jsonSafeValue(readField('version')),
      'updatedAt': _jsonSafeValue(readField('updatedAt')),
      'isDeleted': _jsonSafeValue(readField('isDeleted')),
    };
  }

  String _auditEntityId(dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return firestoreId;
      }
    } catch (_) {
      // Fall through to local id.
    }

    try {
      return record.id.toString();
    } catch (_) {
      return 'unknown';
    }
  }

  void _logConflictAudit(
    String entityLabel,
    dynamic local,
    dynamic remote, {
    String? reasonNotes,
    String? summary,
    AuditAction action = AuditAction.update,
  }) {
    final normalizedEntityType = entityLabel.replaceAll(' ', '_');
    final localMap = _safeAuditMap(local);
    final remoteMap = _safeAuditMap(remote);

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final actorUid = firebaseUser?.uid;
    final actorName =
        firebaseUser?.displayName?.trim().isNotEmpty == true
            ? firebaseUser!.displayName!.trim()
            : firebaseUser?.email?.trim().isNotEmpty == true
            ? firebaseUser!.email!.trim()
            : 'Sync Engine';

    final event = AuditEvent(
      entityType: normalizedEntityType,
      entityId: _auditEntityId(local),
      action: action,
      performedByUid: actorUid ?? 'sync_engine',
      performedByName:
          actorUid == null ? 'Sync Engine' : 'Sync Engine ($actorName)',
      reason: AuditReason.manualOverride,
      reasonNotes:
          reasonNotes ??
          'Sync conflict preserved: unsynced local record was retained because remote was newer.',
      summary: summary ?? 'Sync conflict preserved for $entityLabel',
      severity: AuditSeverity.high,
      before: localMap,
      after: remoteMap,
    );

    unawaited(
      _auditRepo.log(event, syncToRemote: actorUid != null).catchError((
        Object error,
      ) {
        debugPrint('⚠️ Failed to audit sync conflict: $error');
      }),
    );
  }

  void _logPullConflict(String entityLabel, dynamic local, dynamic remote) {
    lastConflicted++;
    lastSkipped++;
    lastConflictKeys.add(_conflictKey(entityLabel, local));
    debugPrint(
      '⚠️ PULL CONFLICT: Retaining unsynced local $entityLabel ${local.id}; '
      'remote is newer and was not applied. firestoreId=${local.firestoreId}, '
      'local.version=${local.version}, remote.version=${remote.version}, '
      'local.updatedAt=${local.updatedAt}, remote.updatedAt=${remote.updatedAt}',
    );
    _logConflictAudit(entityLabel, local, remote);
  }

  void _recordTombstoneApplyResult(
    String entityLabel,
    dynamic remote,
    RemoteTombstoneApplyResult result,
  ) {
    switch (result.outcome) {
      case RemoteTombstoneApplyOutcome.applied:
        lastDeleted++;
        return;
      case RemoteTombstoneApplyOutcome.localDirtyPreserved:
        final local = result.localRecord;
        lastConflicted++;
        lastSkipped++;
        if (local != null) {
          lastConflictKeys.add(_conflictKey(entityLabel, local));
        } else {
          lastConflictKeys.add(_conflictKey(entityLabel, remote));
        }
        debugPrint(
          '⚠️ TOMBSTONE CONFLICT: Retaining fresher unsynced local $entityLabel; '
          'remote tombstone was not applied. firestoreId=${remote.firestoreId}, '
          'remote.deletedAt=${remote.deletedAt}, remote.updatedAt=${remote.updatedAt}',
        );
        if (local != null) {
          _logConflictAudit(
            entityLabel,
            local,
            remote,
            reasonNotes:
                'Sync conflict preserved: remote tombstone conflicted with fresher unsynced local evidence; the remote delete was not applied.',
            summary:
                'Sync conflict preserved for $entityLabel: remote tombstone not applied',
            action: AuditAction.delete,
          );
        }
        return;
      case RemoteTombstoneApplyOutcome.localMissing:
      case RemoteTombstoneApplyOutcome.alreadyDeleted:
      case RemoteTombstoneApplyOutcome.notDeletedRemote:
        lastSkipped++;
        return;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MAINTENANCE (PAGINATED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _pullMaintenance(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreMaintenance.getUpdatedTickets(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final remoteRecords = result.records;
      _observeFetchedRemoteRecords(remoteRecords);
      startAfter = result.lastDoc;

      if (remoteRecords.isEmpty) break;

      final inserts = <MaintenanceRecord>[];
      final updates = <MaintenanceRecord>[];
      final tombstones = <MaintenanceRecord>[];

      for (final remote in remoteRecords) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _maintenanceRepo.getByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('ticket', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Maintenance pull processing error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _maintenanceRepo
            .applyTombstoneFromMaintenanceRemote(remote);
        _recordTombstoneApplyResult('maintenance ticket', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _maintenanceRepo.insertFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _maintenanceRepo.updateFromRemote(remote);
        lastUpdated++;
      }

      if (remoteRecords.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PLANNED MAINTENANCE (PAGINATED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _pullPlanned(DateTime? lastSync) async {
    await _pullTemplateGovernance(lastSync);
    await _pullTemplates(lastSync);
    await _pullExecutions(lastSync);
    await _pullJobDiaryEntries(lastSync);
    await _pullJobModules(lastSync);
  }

  Future<void> _pullTemplateGovernance(DateTime? lastSync) async {
    await _pullTemplatePackages(lastSync);
    await _pullTemplateVersions(lastSync);
    await _pullTemplatePublishAudits(lastSync);
  }

  Future<void> _pullTemplatePackages(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedPackages(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final packages = result.records;
      _observeFetchedRemoteRecords(packages);
      startAfter = result.lastDoc;

      if (packages.isEmpty) break;

      final inserts = <TemplatePackage>[];
      final updates = <TemplatePackage>[];
      final tombstones = <TemplatePackage>[];

      for (final remote in packages) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _templateGovernanceRepo.getPackageByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) tombstones.add(remote);
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('template package', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template package pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _templateGovernanceRepo
            .applyTombstoneFromPackageRemote(remote);
        _recordTombstoneApplyResult('template package', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _templateGovernanceRepo.insertPackageFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _templateGovernanceRepo.updatePackageFromRemote(remote);
        lastUpdated++;
      }

      if (packages.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullTemplateVersions(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedVersions(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final versions = result.records;
      _observeFetchedRemoteRecords(versions);
      startAfter = result.lastDoc;

      if (versions.isEmpty) break;

      final inserts = <TemplateVersion>[];
      final updates = <TemplateVersion>[];
      final tombstones = <TemplateVersion>[];

      for (final remote in versions) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _templateGovernanceRepo.getVersionByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) tombstones.add(remote);
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('template version', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template version pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _templateGovernanceRepo
            .applyTombstoneFromVersionRemote(remote);
        _recordTombstoneApplyResult('template version', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _templateGovernanceRepo.insertVersionFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _templateGovernanceRepo.updateVersionFromRemote(remote);
        lastUpdated++;
      }

      if (versions.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullTemplatePublishAudits(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedAudits(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final audits = result.records;
      _observeFetchedRemoteRecords(audits);
      startAfter = result.lastDoc;

      if (audits.isEmpty) break;

      for (final remote in audits) {
        try {
          if (remote.firestoreId == null) continue;
          final local = await _templateGovernanceRepo.getAuditByFirestoreId(
            remote.firestoreId!,
          );
          if (local != null) {
            lastSkipped++;
            continue;
          }
          remote.isSynced = true;
          await _templateGovernanceRepo.insertAuditFromRemote(remote);
          lastInserted++;
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template publish audit pull error: $e');
        }
      }

      if (audits.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullTemplates(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedTemplates(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final templates = result.records;
      _observeFetchedRemoteRecords(templates);
      startAfter = result.lastDoc;

      if (templates.isEmpty) break;

      final inserts = <JobTemplate>[];
      final updates = <JobTemplate>[];
      final tombstones = <JobTemplate>[];

      for (final remote in templates) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _plannedRepo.getTemplateByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('template', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _plannedRepo.applyTombstoneFromTemplateRemote(
          remote,
        );
        _recordTombstoneApplyResult('job template', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _plannedRepo.insertTemplateFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _plannedRepo.updateTemplateFromRemote(remote);
        lastUpdated++;
      }

      if (templates.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullExecutions(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedExecutions(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final executions = result.records;
      _observeFetchedRemoteRecords(executions);
      startAfter = result.lastDoc;

      if (executions.isEmpty) break;

      final inserts = <JobExecution>[];
      final updates = <JobExecution>[];
      final tombstones = <JobExecution>[];

      for (final remote in executions) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _plannedRepo.getExecutionByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('execution', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Execution pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _plannedRepo.applyTombstoneFromExecutionRemote(
          remote,
        );
        _recordTombstoneApplyResult('job execution', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _plannedRepo.insertExecutionFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _plannedRepo.updateExecutionFromRemote(remote);
        lastUpdated++;
      }

      if (executions.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullJobDiaryEntries(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreJobDiary.getUpdatedEntries(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final entries = result.records;
      _observeFetchedRemoteRecords(entries);
      startAfter = result.lastDoc;

      if (entries.isEmpty) break;

      final inserts = <JobDiaryEntry>[];
      final updates = <JobDiaryEntry>[];
      final tombstones = <JobDiaryEntry>[];

      for (final remote in entries) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _jobDiaryRepo.getEntryByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('job diary entry', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job diary pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _jobDiaryRepo.applyTombstoneFromRemote(remote);
        _recordTombstoneApplyResult('job diary entry', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _jobDiaryRepo.insertEntryFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _jobDiaryRepo.updateEntryFromRemote(remote);
        lastUpdated++;
      }

      if (entries.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullJobModules(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreJobModule.getUpdatedModules(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final modules = result.records;
      _observeFetchedRemoteRecords(modules);
      startAfter = result.lastDoc;

      if (modules.isEmpty) break;

      final inserts = <JobModuleInstance>[];
      final updates = <JobModuleInstance>[];
      final tombstones = <JobModuleInstance>[];

      for (final remote in modules) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _jobModuleRepo.getModuleByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('job module', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job module pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _jobModuleRepo.applyTombstoneFromRemote(remote);
        _recordTombstoneApplyResult('job module', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _jobModuleRepo.insertModuleFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _jobModuleRepo.updateModuleFromRemote(remote);
        lastUpdated++;
      }

      if (modules.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIRECTIVES (PAGINATED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _pullDirectives(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreDirective.getUpdatedDirectives(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final directives = result.records;
      _observeFetchedRemoteRecords(directives);
      startAfter = result.lastDoc;

      if (directives.isEmpty) break;

      final inserts = <OperationalDirective>[];
      final updates = <OperationalDirective>[];
      final tombstones = <OperationalDirective>[];

      for (final remote in directives) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _directiveRepo.getByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('directive', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Directive pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _directiveRepo.applyTombstoneFromDirectiveRemote(
          remote,
        );
        _recordTombstoneApplyResult('operational directive', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _directiveRepo.insertFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _directiveRepo.updateFromRemote(remote);
        lastUpdated++;
      }

      if (directives.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ABNORMALITIES (PAGINATED)
  // ─────────────────────────────────────────────────────────────

  Future<void> _pullAbnormalities(DateTime? lastSync) async {
    await _pullAbnormalityTypes(lastSync);
    await _pullChargeAbnormalities(lastSync);
  }

  Future<void> _pullAbnormalityTypes(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreAbnormality.getUpdatedTypes(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final records = result.records;
      _observeFetchedRemoteRecords(records);
      startAfter = result.lastDoc;

      if (records.isEmpty) break;

      final inserts = <AbnormalityType>[];
      final updates = <AbnormalityType>[];
      final tombstones = <AbnormalityType>[];

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _abnormalityRepo.getTypeByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('abnormality type', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Abnormality type pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _abnormalityRepo.applyTombstoneFromTypeRemote(
          remote,
        );
        _recordTombstoneApplyResult('abnormality type', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _abnormalityRepo.insertTypeFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _abnormalityRepo.updateTypeFromRemote(remote);
        lastUpdated++;
      }

      if (records.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullChargeAbnormalities(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreAbnormality.getUpdatedAbnormalities(
        since: lastSync,
        limit: _pageSize,
        startAfter: startAfter,
      );

      final records = result.records;
      _observeFetchedRemoteRecords(records);
      startAfter = result.lastDoc;

      if (records.isEmpty) break;

      final inserts = <ChargeAbnormality>[];
      final updates = <ChargeAbnormality>[];
      final tombstones = <ChargeAbnormality>[];

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _abnormalityRepo.getAbnormalityByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('charge abnormality', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Charge abnormality pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _abnormalityRepo
            .applyTombstoneFromAbnormalityRemote(remote);
        _recordTombstoneApplyResult('charge abnormality', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _abnormalityRepo.insertAbnormalityFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _abnormalityRepo.updateAbnormalityFromRemote(remote);
        lastUpdated++;
      }

      if (records.length < _pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullKnowledgeBase(DateTime? lastSync) async {
    try {
      final result = await _knowledgeRepo.pullCloudToLocal(lastSync);
      _observeFetchedRemoteUpdatedAt(result.maxFetchedUpdatedAt);
      lastInserted += result.inserted;
      lastUpdated += result.updated;
      lastSkipped += result.skipped;
    } catch (e, stackTrace) {
      _hadRecordProcessingError = true;
      debugPrint('❌ Knowledge Base pull failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDER INJECTION
// ─────────────────────────────────────────────────────────────

final pullServiceProvider = Provider<GlobalPullService>((ref) {
  return GlobalPullService(
    ref.read(maintenanceRepositoryProvider),
    ref.read(firestoreMaintenanceRepo),
    ref.read(plannedRepositoryProvider),
    ref.read(firestorePlannedRepo),
    ref.read(jobDiaryRepositoryProvider),
    ref.read(firestoreJobDiaryRepoProvider),
    ref.read(jobModuleRepositoryProvider),
    ref.read(firestoreJobModuleRepoProvider),
    ref.read(templateGovernanceRepositoryProvider),
    ref.read(firestoreTemplateGovernanceRepo),
    ref.read(directiveRepositoryProvider),
    ref.read(firestoreDirectiveRepo),
    ref.read(abnormalityRepositoryProvider),
    ref.read(firestoreAbnormalityRepoProvider),
    ref.read(bafKnowledgeRepositoryProvider),
    ref.read(auditRepositoryProvider),
  );
});
