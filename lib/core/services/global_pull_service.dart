// FILE: lib/core/services/global_pull_service.dart

import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../features/maintenance/providers/maintenance_provider.dart';
import '../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../features/planned_maintenance/providers/job_diary_provider.dart';
import '../../features/planned_maintenance/providers/job_module_provider.dart';
import '../../features/planned_maintenance/providers/template_governance_provider.dart';
import '../../features/planned_maintenance/domain/baf_knowledge_repository.dart';
import '../../features/directives/providers/operational_directive_provider.dart';
import '../../features/abnormalities/providers/abnormality_provider.dart';
import '../../features/audit/models/audit_event_model.dart';
import '../../features/audit/repositories/audit_repository.dart';
import '../../features/audit/providers/audit_provider.dart';
import 'remote_tombstone_apply_result.dart';
import 'global_pull_cursor_store.dart';
import 'global_pull_protocol.dart';
import 'future_dated_local_timestamp_repair.dart';
import 'isar_schema_migration.dart';
import 'server_anchored_clock.dart';

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

/// Hook run after the backend instant is adopted and before any domain pull.
typedef ServerAnchorAdoptedCallback = Future<void> Function();

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
  final FirebaseAuth? _auth;
  FirebaseAuth get _authentication => _auth ?? FirebaseAuth.instance;

  /// Invoked once the backend instant has been adopted, before any domain is
  /// pulled. Injected rather than called directly so this service keeps its
  /// repository-only contract and stays safe where the local store is absent.
  final ServerAnchorAdoptedCallback? _onServerAnchorAdopted;

  bool _isPulling = false;
  bool _serverAnchorAdoptedHookAttempted = false;
  bool _hadRecordProcessingError = false;
  bool _hadCleanLocalReconciliation = false;
  GlobalPullDomain? lastFailedDomain;

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
    FirebaseAuth? auth,
    ServerAnchorAdoptedCallback? onServerAnchorAdopted,
  }) : _authorityReader =
           authorityReader ?? const FirebaseGlobalPullAuthorityReader(),
       _runIdFactory = runIdFactory ?? const Uuid().v4,
       _auth = auth,
       _onServerAnchorAdopted = onServerAnchorAdopted;

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
    lastFailedDomain = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final actorUid = _authentication.currentUser?.uid;
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
      // The run authority carries the backend's own instant. Adopting it here
      // keeps locally persisted timestamps on the server's timeline, so a
      // device whose clock runs ahead cannot stamp rows that later make a
      // higher server version look stale during ingest.
      ServerAnchoredClock.anchorToServer(serverAnchor: authority.serverAnchor);
      // Rows written before the clock was anchored can already carry instants
      // the backend could not have produced. Those block their domain cursor
      // permanently, so they are re-anchored once per session before any domain
      // is pulled, allowing the same run to advance.
      await _runServerAnchorAdoptedHookOnce();
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
      rethrow;
    } finally {
      _isPulling = false;

      debugPrint(
        'GLOBAL PULL: Inserted: $lastInserted, Updated: $lastUpdated, Deleted: $lastDeleted, Conflicted: $lastConflicted, Skipped: $lastSkipped',
      );
    }
  }

  /// Runs the injected post-anchor hook once per session. Rows written before
  /// the clock was anchored can carry instants the backend could not have
  /// produced, which block their domain cursor permanently; the hook clears
  /// that backlog. A failure must not fail the pull, because the unrepaired
  /// state is exactly what this run is trying to make progress against.
  Future<void> _runServerAnchorAdoptedHookOnce() async {
    final hook = _onServerAnchorAdopted;
    if (hook == null || _serverAnchorAdoptedHookAttempted) return;
    _serverAnchorAdoptedHookAttempted = true;
    try {
      await hook();
    } catch (error, stackTrace) {
      debugPrint('Post-anchor local repair skipped: $error\n$stackTrace');
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
    _hadCleanLocalReconciliation = false;
    try {
      await pull(cursor.cursor, envelope.serverAnchor);
    } catch (_) {
      lastFailedDomain = domain;
      rethrow;
    }
    _requireCurrentActor(envelope.actorUid);
    if (_hadCleanLocalReconciliation) {
      lastFailedDomain = domain;
      throw GlobalPullCursorException(
        'Newer server records in ${domain.wireName} need reconciliation with '
        'preserved local evidence. This domain cursor has not advanced.',
        reasonCode: 'domain-clean-local-reconciliation-required',
      );
    }
    if (_hadRecordProcessingError) {
      lastFailedDomain = domain;
      throw GlobalPullCursorException(
        'Global pull domain ${domain.wireName} had record processing errors.',
        reasonCode: 'domain-record-processing-failed',
      );
    }
    return cursorStore.completeDomain(envelope, domain);
  }

  void _requireCurrentActor(String expectedUid) {
    if (_authentication.currentUser?.uid != expectedUid) {
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
    onServerAnchorAdopted: () => runFutureDatedLocalTimestampRepair(
      auditRepository: ref.read(auditRepositoryProvider),
      actorUid: FirebaseAuth.instance.currentUser?.uid,
    ),
  );
});
