// FILE: lib/core/services/global_pull_service.dart

import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

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
import 'global_pull_cursor_store.dart';
import 'global_pull_protocol.dart';
import 'isar_schema_migration.dart';

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
  final FirestoreJobDiaryRepository _firestoreJobDiary;

  final JobModuleRepository _jobModuleRepo;
  final FirestoreJobModuleRepository _firestoreJobModule;

  final TemplateGovernanceRepository _templateGovernanceRepo;
  final FirestoreTemplateGovernanceRepository _firestoreTemplateGovernance;

  final DirectiveRepository _directiveRepo;
  final FirestoreDirectiveRepository _firestoreDirective;

  final AbnormalityRepository _abnormalityRepo;
  final FirestoreAbnormalityRepository _firestoreAbnormality;

  final BafKnowledgeRepository _knowledgeRepo;

  final AuditRepository _auditRepo;
  final GlobalPullAuthorityReader _authorityReader;
  final String Function() _runIdFactory;

  bool _isPulling = false;
  bool _hadRecordProcessingError = false;

  int lastInserted = 0;
  int lastUpdated = 0;
  int lastSkipped = 0;
  int lastDeleted = 0;
  int lastConflicted = 0;
  final Set<String> lastConflictKeys = <String>{};

  static const int _pageSize = 500;
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
    this._auditRepo, {
    GlobalPullAuthorityReader? authorityReader,
    String Function()? runIdFactory,
  }) : _authorityReader =
           authorityReader ?? const FirebaseGlobalPullAuthorityReader(),
       _runIdFactory = runIdFactory ?? const Uuid().v4;

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

    try {
      final prefs = await SharedPreferences.getInstance();
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      if (actorUid == null || actorUid.trim().isEmpty) {
        throw const GlobalPullProtocolException(
          'Authentication is required before global pull.',
          reasonCode: 'client-actor-unauthenticated',
        );
      }
      final provenance = await IsarSchemaMigrator.readCommittedMarker(
        SharedPreferencesIsarSchemaProvenanceStore(prefs),
      );
      if (provenance == null) {
        throw const GlobalPullCursorException(
          'A committed local database generation is required for global pull.',
          reasonCode: 'cursor-database-generation-unavailable',
        );
      }
      final authority = await _authorityReader.beginRun(expectedUid: actorUid);
      final cursorStore = SharedPreferencesGlobalPullCursorStore(prefs);
      var envelope = await cursorStore.begin(
        actorUid: actorUid,
        databaseGenerationId: provenance.databaseGenerationId,
        authority: authority,
        runId: _runIdFactory(),
      );

      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.knowledgeBase,
        pull: _pullKnowledgeBase,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.maintenanceRecords,
        pull: _pullMaintenance,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.templatePackages,
        pull: _pullTemplatePackages,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.templateVersions,
        pull: _pullTemplateVersions,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.templatePublishAudits,
        pull: _pullTemplatePublishAudits,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.jobTemplates,
        pull: _pullTemplates,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.jobExecutions,
        pull: _pullExecutions,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.jobDiaryEntries,
        pull: _pullJobDiaryEntries,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.jobModules,
        pull: _pullJobModules,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.directives,
        pull: _pullDirectives,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.abnormalityTypes,
        pull: _pullAbnormalityTypes,
      );
      envelope = await _runDomain(
        cursorStore: cursorStore,
        envelope: envelope,
        domain: GlobalPullDomain.chargeAbnormalities,
        pull: _pullChargeAbnormalities,
      );
      _requireCurrentActor(envelope.actorUid);
      await cursorStore.commit(envelope);
    } catch (e, stackTrace) {
      debugPrint('Global pull failed: $e');
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
        'GLOBAL PULL: Inserted: $lastInserted, Updated: $lastUpdated, Deleted: $lastDeleted, Conflicted: $lastConflicted, Skipped: $lastSkipped',
      );
    }
  }

  Future<GlobalPullRunEnvelope> _runDomain({
    required SharedPreferencesGlobalPullCursorStore cursorStore,
    required GlobalPullRunEnvelope envelope,
    required GlobalPullDomain domain,
    required Future<void> Function(DateTime? since, DateTime through) pull,
  }) async {
    final cursor = envelope.cursorFor(domain);
    if (cursor.completedInRun) return envelope;

    _requireCurrentActor(envelope.actorUid);
    _hadRecordProcessingError = false;
    await pull(cursor.cursor, envelope.serverAnchor);
    _requireCurrentActor(envelope.actorUid);
    if (_hadRecordProcessingError) {
      throw GlobalPullCursorException(
        'Global pull domain ${domain.wireName} had record processing errors.',
        reasonCode: 'domain-record-processing-failed',
      );
    }
    return cursorStore.completeDomain(envelope, domain);
  }

  void _requireCurrentActor(String expectedUid) {
    if (FirebaseAuth.instance.currentUser?.uid != expectedUid) {
      throw const GlobalPullCursorException(
        'The authenticated actor changed during global pull.',
        reasonCode: 'cursor-actor-changed-during-run',
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
