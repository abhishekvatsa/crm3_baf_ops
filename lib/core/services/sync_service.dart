import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../providers/sync_status_provider.dart';
import 'app_logger.dart';
import 'sync_push_snapshot.dart';
import 'sync_remote_freshness_policy.dart';
import 'remote_tombstone_apply_result.dart';

import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/providers/maintenance_provider.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import '../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../features/planned_maintenance/services/planned_job_server_completion_service.dart';
import '../../features/planned_maintenance/services/runtime_job_module_population_service.dart';
import '../../features/planned_maintenance/providers/job_diary_provider.dart';
import '../../features/planned_maintenance/providers/job_module_provider.dart';
import '../../features/planned_maintenance/providers/template_governance_provider.dart';
import '../../features/planned_maintenance/domain/baf_knowledge_repository.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/directives/providers/operational_directive_provider.dart';
import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/abnormalities/providers/abnormality_provider.dart';
import '../../features/abnormalities/services/charge_abnormality_command_service.dart';
import '../../features/audit/models/audit_event_model.dart';
import '../../features/audit/repositories/audit_repository.dart';
import '../../features/audit/providers/audit_provider.dart';

part 'sync_service.push_infrastructure.dart';
part 'sync_service.template_governance.dart';
part 'sync_service.tickets_templates.dart';
part 'sync_service.executions.dart';
part 'sync_service.job_diary.dart';
part 'sync_service.job_modules.dart';
part 'sync_service.directives_abnormalities.dart';
part 'sync_service.knowledge_base.dart';

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
  final ChargeAbnormalityCommandService _abnormalityCommands;

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
    ChargeAbnormalityCommandService? abnormalityCommandService,
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
       _abnormalityCommands =
           abnormalityCommandService ?? ChargeAbnormalityCommandService(),
       _knowledgeRepo = knowledgeRepo,
       _auditRepo = auditRepository;

  @visibleForTesting
  Future<void> syncJobModulesForTest() => _syncJobModules();

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
      // ORDER DEPENDENCY: job modules must reach Firestore before completed
      // execution closures are submitted through the Cloud Function. The
      // callable validates canonical remote module state before accepting job
      // completion, so swapping the next two calls can create false server
      // rejections and must be treated as a sync/no-loss behavior change.
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
    abnormalityCommandService: ref.read(
      chargeAbnormalityCommandServiceProvider,
    ),
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
