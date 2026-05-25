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

part 'global_pull_service.watermark.dart';
part 'global_pull_service.conflicts.dart';
part 'global_pull_service.maintenance.dart';
part 'global_pull_service.template_governance.dart';
part 'global_pull_service.planned.dart';
part 'global_pull_service.job_diary.dart';
part 'global_pull_service.job_modules.dart';
part 'global_pull_service.directives.dart';
part 'global_pull_service.abnormalities.dart';
part 'global_pull_service.knowledge_base.dart';

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
