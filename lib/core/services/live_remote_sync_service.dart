// FILE: lib/core/services/live_remote_sync_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart' hide Query;

import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/abnormalities/providers/abnormality_provider.dart';
import '../../features/auth/data/user_model.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/directives/data/remote_operational_directive_reader.dart';
import '../../features/directives/providers/operational_directive_provider.dart';
import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/data/remote_maintenance_reader.dart';
import '../../features/maintenance/providers/maintenance_provider.dart';
import '../../features/maintenance_workflow/data/compliance_request_record.dart';
import '../../features/maintenance_workflow/data/job_lane_record.dart';
import '../../features/maintenance_workflow/data/workflow_aggregate_record.dart';
import '../../features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import '../../features/planned_maintenance/data/baf_knowledge_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import '../../features/planned_maintenance/providers/job_diary_provider.dart';
import '../../features/planned_maintenance/providers/job_module_provider.dart';
import '../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../features/planned_maintenance/providers/template_governance_provider.dart';
import 'app_logger.dart';
import 'remote_tombstone_apply_result.dart';
import 'sync_remote_freshness_policy.dart';

part 'live_remote_sync_service.business.dart';

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

// ─────────────────────────────────────────────────────────────
// LIVE REMOTE SYNC SERVICE
// ─────────────────────────────────────────────────────────────
//
// This is a remote-to-local bridge for urgent operational freshness.
// It does not replace SyncCoordinator, SyncService, or GlobalPullService.
// It listens to selected Firestore queries and mirrors safe remote changes
// into local Isar so existing Isar-backed providers update immediately.
//
// Open maintenance tickets are scoped by actor. Active workflows, directives,
// planned jobs and modules plus bounded recent operational records are kept
// live across devices; the existing role policy still controls presentation.
// SyncCoordinator/GlobalPullService remains the complete recovery authority.

const _activeWorkflowStatuses = <String>[
  'pendingLaneClassification',
  'assigned',
  'partiallyAcknowledged',
  'fullyAcknowledged',
  'inProgress',
  'awaitingCompliance',
  'readyForClosure',
];
const _activeLaneStatuses = <String>['pending', 'acknowledged'];
const _activeComplianceStatuses = <String>[
  'raised',
  'acknowledged',
  'complied',
];

enum LiveRemoteSyncConnectionState {
  disabled,
  disconnected,
  paused,
  listening,
  error,
}

class LiveMaintenanceMirrorScope {
  final String actorUid;
  final bool listenToAllOpenTickets;
  final bool includeOwnLoggedTickets;
  final bool includeCriticalTickets;
  final List<RoutedTo> routedTo;
  final String label;

  const LiveMaintenanceMirrorScope({
    required this.actorUid,
    required this.listenToAllOpenTickets,
    required this.includeOwnLoggedTickets,
    required this.includeCriticalTickets,
    required this.routedTo,
    required this.label,
  });

  factory LiveMaintenanceMirrorScope.disabled(String reason) {
    return LiveMaintenanceMirrorScope(
      actorUid: '',
      listenToAllOpenTickets: false,
      includeOwnLoggedTickets: false,
      includeCriticalTickets: false,
      routedTo: const <RoutedTo>[],
      label: 'Disabled: $reason',
    );
  }

  factory LiveMaintenanceMirrorScope.forUser(AppUser user) {
    if (!user.isApproved) {
      return LiveMaintenanceMirrorScope.disabled('user not approved');
    }

    final broadActor =
        user.isAdmin ||
        user.isSI ||
        user.isContractSupervisor ||
        user.isShiftSupervisor;

    if (broadActor) {
      return LiveMaintenanceMirrorScope(
        actorUid: user.uid,
        listenToAllOpenTickets: true,
        includeOwnLoggedTickets: false,
        includeCriticalTickets: false,
        routedTo: const <RoutedTo>[],
        label: 'All open tickets',
      );
    }

    final routedTargets = _routedTargetsForUser(user);
    final includeCritical = user.isSeniorRole || user.isRefractory;

    return LiveMaintenanceMirrorScope(
      actorUid: user.uid,
      listenToAllOpenTickets: false,
      includeOwnLoggedTickets: true,
      includeCriticalTickets: includeCritical,
      routedTo: routedTargets,
      label: _scopedLabel(
        includeOwn: true,
        includeCritical: includeCritical,
        routedTargets: routedTargets,
      ),
    );
  }

  bool get isDisabled {
    return !listenToAllOpenTickets &&
        !includeOwnLoggedTickets &&
        !includeCriticalTickets &&
        routedTo.isEmpty;
  }

  String get scopeKey {
    final routed = routedTo.map((r) => r.name).toList()..sort();
    return [
      'actor=$actorUid',
      'all=$listenToAllOpenTickets',
      'own=$includeOwnLoggedTickets',
      'critical=$includeCriticalTickets',
      'routed=${routed.join(',')}',
    ].join('|');
  }

  static List<RoutedTo> _routedTargetsForUser(AppUser user) {
    final targets = <RoutedTo>{};

    if (user.isOperations) {
      targets
        ..add(RoutedTo.operations)
        ..add(RoutedTo.shiftInCharge);
    }
    if (user.isMechanical) targets.add(RoutedTo.mechanical);
    if (user.isElectrical) targets.add(RoutedTo.electrical);
    if (user.isInstrumentation) targets.add(RoutedTo.instrumentation);
    if (user.isRefractory) targets.add(RoutedTo.refractory);

    return targets.toList(growable: false);
  }

  static String _scopedLabel({
    required bool includeOwn,
    required bool includeCritical,
    required List<RoutedTo> routedTargets,
  }) {
    final parts = <String>[];
    if (includeOwn) parts.add('own raised tickets');
    if (routedTargets.isNotEmpty) {
      parts.add('routed to ${routedTargets.map((r) => r.name).join('/')}');
    }
    if (includeCritical) parts.add('critical tickets');
    return parts.isEmpty ? 'No live ticket scope' : parts.join(' + ');
  }
}

class LiveRemoteSyncHealth {
  final LiveRemoteSyncConnectionState maintenanceState;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? lastEventAt;
  final DateTime? lastAppliedAt;
  final String? lastError;
  final String? maintenanceScopeLabel;
  final int listenerCount;
  final int appliedCount;
  final int skippedUnsyncedLocalCount;
  final int removedEventCount;
  final int pauseCount;
  final int resumeCount;

  const LiveRemoteSyncHealth({
    this.maintenanceState = LiveRemoteSyncConnectionState.disconnected,
    this.startedAt,
    this.pausedAt,
    this.lastEventAt,
    this.lastAppliedAt,
    this.lastError,
    this.maintenanceScopeLabel,
    this.listenerCount = 0,
    this.appliedCount = 0,
    this.skippedUnsyncedLocalCount = 0,
    this.removedEventCount = 0,
    this.pauseCount = 0,
    this.resumeCount = 0,
  });

  bool get isListening =>
      maintenanceState == LiveRemoteSyncConnectionState.listening;

  bool get isPaused => maintenanceState == LiveRemoteSyncConnectionState.paused;

  bool get hasError => maintenanceState == LiveRemoteSyncConnectionState.error;

  LiveRemoteSyncHealth copyWith({
    LiveRemoteSyncConnectionState? maintenanceState,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    DateTime? lastEventAt,
    DateTime? lastAppliedAt,
    String? lastError,
    bool clearLastError = false,
    String? maintenanceScopeLabel,
    bool clearMaintenanceScopeLabel = false,
    int? listenerCount,
    int? appliedCount,
    int? skippedUnsyncedLocalCount,
    int? removedEventCount,
    int? pauseCount,
    int? resumeCount,
  }) {
    return LiveRemoteSyncHealth(
      maintenanceState: maintenanceState ?? this.maintenanceState,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      lastEventAt: lastEventAt ?? this.lastEventAt,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      maintenanceScopeLabel: clearMaintenanceScopeLabel
          ? null
          : (maintenanceScopeLabel ?? this.maintenanceScopeLabel),
      listenerCount: listenerCount ?? this.listenerCount,
      appliedCount: appliedCount ?? this.appliedCount,
      skippedUnsyncedLocalCount:
          skippedUnsyncedLocalCount ?? this.skippedUnsyncedLocalCount,
      removedEventCount: removedEventCount ?? this.removedEventCount,
      pauseCount: pauseCount ?? this.pauseCount,
      resumeCount: resumeCount ?? this.resumeCount,
    );
  }
}

final liveRemoteSyncHealthProvider = StateProvider<LiveRemoteSyncHealth>((ref) {
  return const LiveRemoteSyncHealth(
    maintenanceState: kIsWeb
        ? LiveRemoteSyncConnectionState.disabled
        : LiveRemoteSyncConnectionState.disconnected,
  );
});

typedef LiveRemoteSyncProviderReader =
    T Function<T>(ProviderListenable<T> provider);

class LiveRemoteSyncService {
  final Isar _isar;
  final LiveRemoteSyncProviderReader _read;
  final MaintenanceRepository _maintenanceRepository;
  final DirectiveRepository _directiveRepository;
  final PlannedMaintenanceRepository _plannedRepository;
  final JobModuleRepository _jobModuleRepository;
  final JobDiaryRepository _jobDiaryRepository;
  final AbnormalityRepository _abnormalityRepository;
  final TemplateGovernanceRepository _templateGovernanceRepository;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _maintenanceSubs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final Set<_LiveRemoteMirrorKind> _reconciledProjectionKinds =
      <_LiveRemoteMirrorKind>{};
  final Set<_LiveBusinessMirrorKind> _reconciledBusinessKinds =
      <_LiveBusinessMirrorKind>{};
  final Map<_LiveRemoteMirrorKind, Timer> _projectionReconciliationRetries =
      <_LiveRemoteMirrorKind, Timer>{};
  final Map<_LiveRemoteMirrorKind, int> _projectionReconciliationFailures =
      <_LiveRemoteMirrorKind, int>{};
  final Map<_LiveBusinessMirrorKind, Timer> _businessReconciliationRetries =
      <_LiveBusinessMirrorKind, Timer>{};
  final Map<_LiveBusinessMirrorKind, int> _businessReconciliationFailures =
      <_LiveBusinessMirrorKind, int>{};
  final Map<String, Set<String>> _authoritativeTicketIdsByListener =
      <String, Set<String>>{};
  final Set<String> _expectedTicketListeners = <String>{};
  final Map<String, int> _cleanLocalReconciliationVersions = <String, int>{};
  bool _initialTicketReconciliationComplete = false;
  Timer? _ticketReconciliationRetry;
  int _ticketReconciliationFailures = 0;

  LiveMaintenanceMirrorScope? _maintenanceScope;
  bool _maintenanceStarted = false;
  bool _pausedForLifecycle = false;
  int _lifecycleGeneration = 0;

  LiveRemoteSyncService(
    this._isar,
    this._read, {
    MaintenanceRepository? maintenanceRepository,
    DirectiveRepository? directiveRepository,
    PlannedMaintenanceRepository? plannedRepository,
    JobModuleRepository? jobModuleRepository,
    JobDiaryRepository? jobDiaryRepository,
    AbnormalityRepository? abnormalityRepository,
    TemplateGovernanceRepository? templateGovernanceRepository,
  }) : _maintenanceRepository =
           maintenanceRepository ?? IsarMaintenanceRepository(),
       _directiveRepository = directiveRepository ?? IsarDirectiveRepository(),
       _plannedRepository = plannedRepository ?? IsarPlannedRepository(),
       _jobModuleRepository = jobModuleRepository ?? IsarJobModuleRepository(),
       _jobDiaryRepository = jobDiaryRepository ?? IsarJobDiaryRepository(),
       _abnormalityRepository =
           abnormalityRepository ?? IsarAbnormalityRepository(),
       _templateGovernanceRepository =
           templateGovernanceRepository ?? IsarTemplateGovernanceRepository();

  void startMaintenanceOpenTicketMirror({required AppUser actor}) {
    final scope = LiveMaintenanceMirrorScope.forUser(actor);
    _startMaintenanceMirrorForScope(scope);
  }

  void pauseForLifecycle({String reason = 'app_backgrounded'}) {
    if (kIsWeb || _pausedForLifecycle) return;

    _pausedForLifecycle = true;
    _cancelMaintenanceSubscriptions();
    _maintenanceStarted = false;

    final pausedAt = DateTime.now();
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.paused,
        pausedAt: pausedAt,
        listenerCount: 0,
        pauseCount: _health.pauseCount + 1,
        clearLastError: true,
      ),
    );

    AppLogger.info(
      'Live maintenance listener paused',
      context: {
        'app_area': 'live_remote_sync',
        'live_scope': _maintenanceScope?.label ?? '',
        'live_pause_reason': reason,
      },
    );
  }

  void resumeAfterLifecyclePause() {
    if (kIsWeb || !_pausedForLifecycle) return;

    _pausedForLifecycle = false;
    final scope = _maintenanceScope;

    _setHealth(
      _health.copyWith(
        resumeCount: _health.resumeCount + 1,
        clearPausedAt: true,
        clearLastError: true,
      ),
    );

    if (scope == null) {
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.disconnected,
          listenerCount: 0,
          clearStartedAt: true,
        ),
      );
      return;
    }

    _startMaintenanceMirrorForScope(scope, forceRestart: true);
  }

  void stop() {
    _pausedForLifecycle = false;
    _maintenanceStarted = false;
    _maintenanceScope = null;
    _cleanLocalReconciliationVersions.clear();
    _cancelMaintenanceSubscriptions();

    _setHealth(
      _health.copyWith(
        maintenanceState: kIsWeb
            ? LiveRemoteSyncConnectionState.disabled
            : LiveRemoteSyncConnectionState.disconnected,
        listenerCount: 0,
        clearStartedAt: true,
        clearPausedAt: true,
        clearMaintenanceScopeLabel: true,
      ),
    );
  }

  void dispose() => stop();

  void _startMaintenanceMirrorForScope(
    LiveMaintenanceMirrorScope scope, {
    bool forceRestart = false,
  }) {
    final previousScopeKey = _maintenanceScope?.scopeKey;
    if (_maintenanceScope?.actorUid != scope.actorUid) {
      _cleanLocalReconciliationVersions.clear();
    }
    _maintenanceScope = scope;

    if (kIsWeb) {
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.disabled,
          clearStartedAt: true,
          listenerCount: 0,
          maintenanceScopeLabel: scope.label,
        ),
      );
      return;
    }

    if (_pausedForLifecycle) {
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.paused,
          maintenanceScopeLabel: scope.label,
          listenerCount: 0,
        ),
      );
      return;
    }

    if (_maintenanceStarted &&
        !forceRestart &&
        previousScopeKey == scope.scopeKey) {
      return;
    }

    _cancelMaintenanceSubscriptions();
    _maintenanceStarted = false;

    if (scope.isDisabled) {
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.disabled,
          maintenanceScopeLabel: scope.label,
          listenerCount: 0,
          clearStartedAt: true,
          clearPausedAt: true,
          clearLastError: true,
        ),
      );
      return;
    }

    final listenerSpecs = <_LiveRemoteListenerSpec>[
      ..._maintenanceListenerSpecs(scope),
      ..._workflowProjectionListenerSpecs(),
    ];
    final businessSpecs = _businessListenerSpecs();
    if (listenerSpecs.isEmpty) {
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.disabled,
          maintenanceScopeLabel: scope.label,
          listenerCount: 0,
          clearStartedAt: true,
          clearPausedAt: true,
          clearLastError: true,
        ),
      );
      return;
    }

    _maintenanceStarted = true;
    final generation = _lifecycleGeneration;
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
        startedAt: DateTime.now(),
        clearPausedAt: true,
        clearLastError: true,
        maintenanceScopeLabel: scope.label,
        listenerCount: listenerSpecs.length + businessSpecs.length,
      ),
    );

    unawaited(
      AppLogger.setCustomKeys({
        'live_maintenance_state': 'listening',
        'live_maintenance_scope': scope.label,
        'live_maintenance_listener_count':
            listenerSpecs.length + businessSpecs.length,
      }),
    );

    _expectedTicketListeners.addAll(
      listenerSpecs
          .where((spec) => spec.kind == _LiveRemoteMirrorKind.maintenanceTicket)
          .map((spec) => spec.label),
    );
    for (final spec in listenerSpecs) {
      final sub = spec.query
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) => _handleLiveSnapshot(
              spec.kind,
              snapshot,
              listenerLabel: spec.label,
              generation: generation,
            ),
            onError: (Object error, StackTrace stackTrace) {
              if (!_acceptsLiveWork(generation)) return;
              debugPrint(
                '⚠️ Live maintenance listener failed (${spec.label}): $error',
              );
              debugPrintStack(stackTrace: stackTrace);
              AppLogger.warning(
                'Live maintenance listener failed',
                error: error,
                stackTrace: stackTrace,
                context: {
                  'app_area': 'live_remote_sync',
                  'live_query': spec.label,
                  'live_scope': scope.label,
                },
              );
              _setHealth(
                _health.copyWith(
                  maintenanceState: LiveRemoteSyncConnectionState.error,
                  lastError: '$error',
                ),
              );
            },
            onDone: () {
              if (!_acceptsLiveWork(generation)) return;
              _setHealth(
                _health.copyWith(
                  maintenanceState: LiveRemoteSyncConnectionState.disconnected,
                  listenerCount: 0,
                ),
              );
            },
          );
      _maintenanceSubs.add(sub);
    }

    for (final spec in businessSpecs) {
      _startBusinessListener(spec, generation);
    }
  }

  List<_LiveRemoteListenerSpec> _maintenanceListenerSpecs(
    LiveMaintenanceMirrorScope scope,
  ) {
    final base = FirebaseFirestore.instance
        .collection('maintenance_records')
        .where('isDeleted', isEqualTo: false)
        .where('isResolved', isEqualTo: false);

    if (scope.listenToAllOpenTickets) {
      return <_LiveRemoteListenerSpec>[
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.maintenanceTicket,
          label: 'all_open',
          query: base,
        ),
      ];
    }

    final specs = <_LiveRemoteListenerSpec>[];

    if (scope.includeOwnLoggedTickets && scope.actorUid.trim().isNotEmpty) {
      specs.add(
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.maintenanceTicket,
          label: 'own_logged',
          query: base.where('loggedByUid', isEqualTo: scope.actorUid),
        ),
      );
    }

    for (final routedTo in scope.routedTo) {
      specs.addAll(<_LiveRemoteListenerSpec>[
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.maintenanceTicket,
          label: 'lane_${routedTo.name}',
          query: base.where('issueAssignedLanes', arrayContains: routedTo.name),
        ),
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.maintenanceTicket,
          label: 'legacy_routed_${routedTo.name}',
          query: base.where('routedTo', isEqualTo: routedTo.name),
        ),
      ]);
    }

    if (scope.includeCriticalTickets) {
      specs.add(
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.maintenanceTicket,
          label: 'critical',
          query: base.where('isCritical', isEqualTo: true),
        ),
      );
    }

    return specs;
  }

  List<_LiveRemoteListenerSpec> _workflowProjectionListenerSpecs() =>
      <_LiveRemoteListenerSpec>[
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.workflow,
          label: 'active_workflows',
          query: FirebaseFirestore.instance
              .collection('maintenance_workflows')
              .where('status', whereIn: _activeWorkflowStatuses),
        ),
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.lane,
          label: 'active_lanes',
          query: FirebaseFirestore.instance
              .collection('job_lanes')
              .where('status', whereIn: _activeLaneStatuses),
        ),
        _LiveRemoteListenerSpec(
          kind: _LiveRemoteMirrorKind.compliance,
          label: 'active_compliance',
          query: FirebaseFirestore.instance
              .collection('compliance_requests')
              .where('status', whereIn: _activeComplianceStatuses),
        ),
      ];

  void _cancelMaintenanceSubscriptions() {
    _lifecycleGeneration++;
    final subs =
        List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>.from(
          _maintenanceSubs,
        );
    _maintenanceSubs.clear();
    _authoritativeTicketIdsByListener.clear();
    _expectedTicketListeners.clear();
    _initialTicketReconciliationComplete = false;
    _ticketReconciliationRetry?.cancel();
    _ticketReconciliationRetry = null;
    _ticketReconciliationFailures = 0;
    _reconciledBusinessKinds.clear();
    _reconciledProjectionKinds.clear();
    for (final retry in _projectionReconciliationRetries.values) {
      retry.cancel();
    }
    _projectionReconciliationRetries.clear();
    _projectionReconciliationFailures.clear();
    for (final retry in _businessReconciliationRetries.values) {
      retry.cancel();
    }
    _businessReconciliationRetries.clear();
    _businessReconciliationFailures.clear();

    for (final sub in subs) {
      unawaited(sub.cancel());
    }
  }

  bool _acceptsLiveWork(int generation) => liveRemoteSyncGenerationIsCurrent(
    capturedGeneration: generation,
    currentGeneration: _lifecycleGeneration,
    started: _maintenanceStarted,
    paused: _pausedForLifecycle,
  );

  void _handleMaintenanceSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String listenerLabel,
    required int generation,
  }) {
    if (!_acceptsLiveWork(generation)) return;
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
        lastEventAt: DateTime.now(),
        clearLastError: true,
      ),
    );

    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          unawaited(_applyMaintenanceDoc(change.doc, generation: generation));
          break;
        case DocumentChangeType.removed:
          _setHealth(
            _health.copyWith(removedEventCount: _health.removedEventCount + 1),
          );
          // A removed change from this query usually means the ticket was
          // resolved, soft-deleted, or moved outside the scoped query. Fetch the
          // document directly to apply its full current state rather than
          // guessing from query removal alone.
          unawaited(
            _applyRemovedMaintenanceDoc(
              change.doc.reference,
              generation: generation,
            ),
          );
          break;
      }
    }

    if (!snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites) {
      _authoritativeTicketIdsByListener[listenerLabel] = snapshot.docs
          .map((document) => document.id)
          .toSet();
      if (!_initialTicketReconciliationComplete &&
          _expectedTicketListeners.every(
            _authoritativeTicketIdsByListener.containsKey,
          )) {
        _initialTicketReconciliationComplete = true;
        unawaited(_reconcileInitiallyVisibleMaintenanceTickets(generation));
      }
    }
  }

  Future<void> _reconcileInitiallyVisibleMaintenanceTickets(
    int generation,
  ) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final remoteIds = <String>{
        for (final ids in _authoritativeTicketIdsByListener.values) ...ids,
      };
      final scope = _maintenanceScope;
      if (scope == null) {
        return;
      }

      final records = await _isar.maintenanceRecords
          .filter()
          .isResolvedEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .findAll();
      if (!_acceptsLiveWork(generation)) return;
      for (final record in records) {
        if (!_acceptsLiveWork(generation)) return;
        final identifier = record.firestoreId?.trim();
        if (!record.isSynced ||
            identifier == null ||
            identifier.isEmpty ||
            remoteIds.contains(identifier) ||
            !_ticketBelongsToScope(record, scope)) {
          continue;
        }
        await _applyRemovedMaintenanceDoc(
          FirebaseFirestore.instance
              .collection('maintenance_records')
              .doc(identifier),
          generation: generation,
          propagateFailure: true,
        );
      }
      if (!_acceptsLiveWork(generation)) return;
      _ticketReconciliationFailures = 0;
      _ticketReconciliationRetry?.cancel();
      _ticketReconciliationRetry = null;
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      _initialTicketReconciliationComplete = false;
      _recordWorkflowProjectionError(
        kind: _LiveRemoteMirrorKind.maintenanceTicket,
        documentId: '*',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleMaintenanceTicketReconciliationRetry(generation);
    }
  }

  void _scheduleMaintenanceTicketReconciliationRetry(int generation) {
    if (!_acceptsLiveWork(generation)) {
      return;
    }

    _ticketReconciliationFailures += 1;
    final delay = liveWorkflowProjectionReconciliationRetryDelay(
      _ticketReconciliationFailures,
    );
    if (delay == null) {
      return;
    }

    _ticketReconciliationRetry?.cancel();
    _ticketReconciliationRetry = Timer(delay, () {
      _ticketReconciliationRetry = null;
      if (!_acceptsLiveWork(generation) ||
          _initialTicketReconciliationComplete ||
          !_expectedTicketListeners.every(
            _authoritativeTicketIdsByListener.containsKey,
          )) {
        return;
      }
      _initialTicketReconciliationComplete = true;
      unawaited(_reconcileInitiallyVisibleMaintenanceTickets(generation));
    });
  }

  bool _ticketBelongsToScope(
    MaintenanceRecord record,
    LiveMaintenanceMirrorScope scope,
  ) {
    if (scope.listenToAllOpenTickets) return true;
    if (scope.includeOwnLoggedTickets && record.loggedByUid == scope.actorUid) {
      return true;
    }
    if (scope.includeCriticalTickets && record.isCritical) return true;
    final plan = record.issueLanePlanReadResult.value;
    final assigned = plan?.assignedLanes ?? <String>[record.routedTo.name];
    return scope.routedTo.any((route) => assigned.contains(route.name));
  }

  Future<void> _reconcileActiveWorkflowProjections(
    _LiveRemoteMirrorKind kind,
    Set<String> activeRemoteIds,
    int generation,
  ) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final staleIds = <String>[];
      switch (kind) {
        case _LiveRemoteMirrorKind.workflow:
          final rows = await _isar.workflowAggregateRecords.where().findAll();
          staleIds.addAll(
            rows
                .where(
                  (row) =>
                      _activeWorkflowStatuses.contains(row.statusKey) &&
                      !activeRemoteIds.contains(row.firestoreId),
                )
                .map((row) => row.firestoreId),
          );
          break;
        case _LiveRemoteMirrorKind.lane:
          final rows = await _isar.jobLaneRecords.where().findAll();
          staleIds.addAll(
            rows
                .where(
                  (row) =>
                      row.isSynced &&
                      row.firestoreId != null &&
                      _activeLaneStatuses.contains(row.statusKey) &&
                      !activeRemoteIds.contains(row.firestoreId),
                )
                .map((row) => row.firestoreId!),
          );
          break;
        case _LiveRemoteMirrorKind.compliance:
          final rows = await _isar.complianceRequestRecords.where().findAll();
          staleIds.addAll(
            rows
                .where(
                  (row) =>
                      row.isSynced &&
                      row.firestoreId != null &&
                      _activeComplianceStatuses.contains(row.statusKey) &&
                      !activeRemoteIds.contains(row.firestoreId),
                )
                .map((row) => row.firestoreId!),
          );
          break;
        case _LiveRemoteMirrorKind.maintenanceTicket:
          return;
      }
      if (!_acceptsLiveWork(generation)) return;

      final collectionName = switch (kind) {
        _LiveRemoteMirrorKind.workflow => 'maintenance_workflows',
        _LiveRemoteMirrorKind.lane => 'job_lanes',
        _LiveRemoteMirrorKind.compliance => 'compliance_requests',
        _LiveRemoteMirrorKind.maintenanceTicket => throw StateError(
          'Maintenance tickets use their dedicated reconciler.',
        ),
      };
      for (final documentId in staleIds) {
        if (!_acceptsLiveWork(generation)) return;
        await _applyRemovedWorkflowProjectionDoc(
          kind,
          FirebaseFirestore.instance.collection(collectionName).doc(documentId),
          generation: generation,
          propagateFailure: true,
        );
      }
      if (!_acceptsLiveWork(generation)) return;
      _projectionReconciliationFailures.remove(kind);
      _projectionReconciliationRetries.remove(kind)?.cancel();
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      _reconciledProjectionKinds.remove(kind);
      _recordWorkflowProjectionError(
        kind: kind,
        documentId: '*',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleWorkflowProjectionReconciliationRetry(
        kind,
        activeRemoteIds,
        generation,
      );
    }
  }

  void _scheduleWorkflowProjectionReconciliationRetry(
    _LiveRemoteMirrorKind kind,
    Set<String> activeRemoteIds,
    int generation,
  ) {
    if (!_acceptsLiveWork(generation)) return;

    final failures = (_projectionReconciliationFailures[kind] ?? 0) + 1;
    _projectionReconciliationFailures[kind] = failures;
    final delay = liveWorkflowProjectionReconciliationRetryDelay(failures);
    if (delay == null) return;

    _projectionReconciliationRetries.remove(kind)?.cancel();
    _projectionReconciliationRetries[kind] = Timer(delay, () {
      _projectionReconciliationRetries.remove(kind);
      if (!_acceptsLiveWork(generation) ||
          !_reconciledProjectionKinds.add(kind)) {
        return;
      }
      unawaited(
        _reconcileActiveWorkflowProjections(kind, activeRemoteIds, generation),
      );
    });
  }

  void _handleLiveSnapshot(
    _LiveRemoteMirrorKind kind,
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String listenerLabel,
    required int generation,
  }) {
    if (!_acceptsLiveWork(generation)) return;
    if (kind == _LiveRemoteMirrorKind.maintenanceTicket) {
      _handleMaintenanceSnapshot(
        snapshot,
        listenerLabel: listenerLabel,
        generation: generation,
      );
      return;
    }

    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
        lastEventAt: DateTime.now(),
        clearLastError: true,
      ),
    );

    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          unawaited(
            _applyWorkflowProjectionDoc(
              kind,
              change.doc,
              generation: generation,
            ),
          );
          break;
        case DocumentChangeType.removed:
          unawaited(
            _applyRemovedWorkflowProjectionDoc(
              kind,
              change.doc.reference,
              generation: generation,
            ),
          );
          break;
      }
    }

    if (!snapshot.metadata.isFromCache &&
        !snapshot.metadata.hasPendingWrites &&
        _reconciledProjectionKinds.add(kind)) {
      unawaited(
        _reconcileActiveWorkflowProjections(
          kind,
          snapshot.docs.map((doc) => doc.id).toSet(),
          generation,
        ),
      );
    }
  }

  Future<void> _applyRemovedWorkflowProjectionDoc(
    _LiveRemoteMirrorKind kind,
    DocumentReference<Map<String, dynamic>> reference, {
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final doc = await reference.get(const GetOptions(source: Source.server));
      if (!_acceptsLiveWork(generation)) return;
      if (doc.exists) {
        await _applyWorkflowProjectionDoc(
          kind,
          doc,
          generation: generation,
          propagateFailure: propagateFailure,
        );
      } else {
        await _removeWorkflowProjection(kind, reference.id, generation);
      }
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      if (propagateFailure) rethrow;
      _recordWorkflowProjectionError(
        kind: kind,
        documentId: reference.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _applyWorkflowProjectionDoc(
    _LiveRemoteMirrorKind kind,
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    final data = doc.data();
    if (data == null || doc.metadata.hasPendingWrites) return;

    try {
      var applied = false;
      await _isar.writeTxn(() async {
        if (!_acceptsLiveWork(generation)) return;
        switch (kind) {
          case _LiveRemoteMirrorKind.workflow:
            final remote = workflowAggregateRecordFromFirestoreData(
              documentId: doc.id,
              data: data,
            );
            final local = await _isar.workflowAggregateRecords
                .filter()
                .firestoreIdEqualTo(doc.id)
                .findFirst();
            if (!shouldApplyLiveWorkflowProjection(
              localVersion: local?.version,
              localUpdatedAt: local?.updatedAt,
              remoteVersion: remote.version,
              remoteUpdatedAt: remote.updatedAt,
            )) {
              return;
            }
            if (local != null) remote.id = local.id;
            await _isar.workflowAggregateRecords.put(remote);
            applied = true;
            break;
          case _LiveRemoteMirrorKind.lane:
            final remote = jobLaneRecordFromFirestoreData(
              documentId: doc.id,
              data: data,
            );
            final local = await _isar.jobLaneRecords
                .filter()
                .firestoreIdEqualTo(doc.id)
                .findFirst();
            if (!shouldApplyLiveWorkflowProjection(
              localVersion: local?.version,
              localUpdatedAt: local?.updatedAt,
              localIsSynced: local?.isSynced,
              remoteVersion: remote.version,
              remoteUpdatedAt: remote.updatedAt,
            )) {
              return;
            }
            if (local != null) remote.id = local.id;
            await _isar.jobLaneRecords.put(remote);
            applied = true;
            break;
          case _LiveRemoteMirrorKind.compliance:
            final remote = complianceRequestRecordFromFirestoreData(
              documentId: doc.id,
              data: data,
            );
            final local = await _isar.complianceRequestRecords
                .filter()
                .firestoreIdEqualTo(doc.id)
                .findFirst();
            if (!shouldApplyLiveWorkflowProjection(
              localVersion: local?.version,
              localUpdatedAt: local?.updatedAt,
              localIsSynced: local?.isSynced,
              remoteVersion: remote.version,
              remoteUpdatedAt: remote.updatedAt,
            )) {
              return;
            }
            if (local != null) remote.id = local.id;
            await _isar.complianceRequestRecords.put(remote);
            applied = true;
            break;
          case _LiveRemoteMirrorKind.maintenanceTicket:
            throw StateError(
              'Maintenance tickets use their dedicated applier.',
            );
        }
      });

      if (!_acceptsLiveWork(generation)) return;
      if (applied) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            lastAppliedAt: DateTime.now(),
            appliedCount: _health.appliedCount + 1,
            clearLastError: true,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      if (propagateFailure) rethrow;
      _recordWorkflowProjectionError(
        kind: kind,
        documentId: doc.id,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _removeWorkflowProjection(
    _LiveRemoteMirrorKind kind,
    String documentId,
    int generation,
  ) async {
    if (!_acceptsLiveWork(generation)) return;
    await _isar.writeTxn(() async {
      if (!_acceptsLiveWork(generation)) return;
      switch (kind) {
        case _LiveRemoteMirrorKind.workflow:
          final local = await _isar.workflowAggregateRecords
              .filter()
              .firestoreIdEqualTo(documentId)
              .findFirst();
          if (local != null) {
            await _isar.workflowAggregateRecords.delete(local.id);
          }
          break;
        case _LiveRemoteMirrorKind.lane:
          final local = await _isar.jobLaneRecords
              .filter()
              .firestoreIdEqualTo(documentId)
              .findFirst();
          if (local != null && local.isSynced) {
            await _isar.jobLaneRecords.delete(local.id);
          }
          break;
        case _LiveRemoteMirrorKind.compliance:
          final local = await _isar.complianceRequestRecords
              .filter()
              .firestoreIdEqualTo(documentId)
              .findFirst();
          if (local != null && local.isSynced) {
            await _isar.complianceRequestRecords.delete(local.id);
          }
          break;
        case _LiveRemoteMirrorKind.maintenanceTicket:
          break;
      }
    });
  }

  void _recordWorkflowProjectionError({
    required _LiveRemoteMirrorKind kind,
    required String documentId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.warning(
      'Failed to apply live workflow projection',
      error: error,
      stackTrace: stackTrace,
      context: {
        'app_area': 'live_remote_sync',
        'entity_type': kind.name,
        'document_id': documentId,
      },
    );
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.error,
        lastError: '$error',
      ),
    );
  }

  Future<void> _applyRemovedMaintenanceDoc(
    DocumentReference<Map<String, dynamic>> reference, {
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    try {
      final doc = await reference.get(const GetOptions(source: Source.server));
      if (!_acceptsLiveWork(generation)) return;
      if (!doc.exists) {
        await _isar.writeTxn(() async {
          if (!_acceptsLiveWork(generation)) return;
          final locals = await _isar.maintenanceRecords
              .filter()
              .firestoreIdEqualTo(reference.id)
              .findAll();
          for (final local in locals) {
            if (local.isSynced) {
              await _isar.maintenanceRecords.delete(local.id);
            }
          }
        });
        return;
      }
      await _applyMaintenanceDoc(
        doc,
        generation: generation,
        propagateFailure: propagateFailure,
      );
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      if (propagateFailure) {
        rethrow;
      }
      debugPrint('⚠️ Failed to fetch removed live maintenance doc: $error');
      debugPrintStack(stackTrace: stackTrace);
      AppLogger.warning(
        'Failed to fetch removed live maintenance doc',
        error: error,
        stackTrace: stackTrace,
        context: const {'app_area': 'live_remote_sync'},
      );
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.error,
          lastError: '$error',
        ),
      );
    }
  }

  Future<void> _applyMaintenanceDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required int generation,
    bool propagateFailure = false,
  }) async {
    if (!_acceptsLiveWork(generation)) return;
    final data = doc.data();
    if (data == null || doc.metadata.hasPendingWrites) return;

    try {
      final remote = _mapTicket(doc, data);
      if (remote.firestoreId == null) return;
      final receipt = remote.isDeleted
          ? _remoteMirrorReceiptFromTombstone(
              await _maintenanceRepository.applyTombstoneFromMaintenanceRemote(
                remote,
              ),
            )
          : _remoteMirrorReceiptFromRecord(
              await _maintenanceRepository.applyMaintenanceRecordFromRemote(
                remote,
              ),
            );

      if (!_acceptsLiveWork(generation)) return;
      if (_trackCleanLocalReconciliation(
        'maintenance_records/${doc.id}',
        receipt,
        remoteVersion: remote.version,
        propagateFailure: propagateFailure,
      )) {
        return;
      }
      if (receipt.outcome == _RemoteMirrorApplyOutcome.duplicateLocalIdentity) {
        throw StateError(
          'Live maintenance mirror found ${receipt.duplicateCount} local rows '
          'for remote identity ${remote.firestoreId}.',
        );
      }
      if (receipt.outcome == _RemoteMirrorApplyOutcome.applied) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            lastAppliedAt: DateTime.now(),
            appliedCount: _health.appliedCount + 1,
            clearLastError: true,
          ),
        );
      } else if (receipt.outcome ==
          _RemoteMirrorApplyOutcome.localDirtyPreserved) {
        _setHealth(
          _health.copyWith(
            skippedUnsyncedLocalCount: _health.skippedUnsyncedLocalCount + 1,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!_acceptsLiveWork(generation)) return;
      if (propagateFailure) {
        rethrow;
      }
      debugPrint('⚠️ Failed to apply live maintenance doc ${doc.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      AppLogger.warning(
        'Failed to apply live maintenance doc',
        error: error,
        stackTrace: stackTrace,
        context: const {
          'app_area': 'live_remote_sync',
          'entity_type': 'maintenance_record',
        },
      );
      _setHealth(
        _health.copyWith(
          maintenanceState: LiveRemoteSyncConnectionState.error,
          lastError: '$error',
        ),
      );
    }
  }

  MaintenanceRecord _mapTicket(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> d,
  ) => readRemoteMaintenanceRecord(d, documentId: doc.id);

  LiveRemoteSyncHealth get _health => _read(liveRemoteSyncHealthProvider);

  bool _trackCleanLocalReconciliation(
    String key,
    _RemoteMirrorApplyReceipt receipt, {
    required int remoteVersion,
    required bool propagateFailure,
  }) {
    if (receipt.outcome ==
        _RemoteMirrorApplyOutcome.cleanLocalReconciliationRequired) {
      final pendingVersion = _cleanLocalReconciliationVersions[key];
      if (pendingVersion == null || remoteVersion > pendingVersion) {
        _cleanLocalReconciliationVersions[key] = remoteVersion;
      }
      _setHealth(_health);
      if (propagateFailure) {
        throw const RemoteRecordReconciliationRequiredException();
      }
      return true;
    }
    // An unrelated success or an older snapshot is not evidence that a
    // previously rejected higher server version has been reconciled.
    if (receipt.outcome == _RemoteMirrorApplyOutcome.applied ||
        receipt.outcome == _RemoteMirrorApplyOutcome.unchanged) {
      final pendingVersion = _cleanLocalReconciliationVersions[key];
      final resolved =
          pendingVersion != null && remoteVersion >= pendingVersion;
      if (resolved) _cleanLocalReconciliationVersions.remove(key);
      if (resolved && _cleanLocalReconciliationVersions.isEmpty) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            clearLastError: true,
          ),
        );
      }
    }
    return false;
  }

  void _setHealth(LiveRemoteSyncHealth health) {
    if (_cleanLocalReconciliationVersions.isNotEmpty) {
      health = health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.error,
        lastError:
            '${_cleanLocalReconciliationVersions.length} saved record(s) need '
            'reconciliation with newer server versions. Local work has been '
            'preserved.',
      );
    }
    _read(liveRemoteSyncHealthProvider.notifier).state = health;
  }

  /// Exercises normal snapshot decoding, native application and health without
  /// opening cloud listeners. Production starts the mirror through actor scope.
  @visibleForTesting
  Future<void> applyMaintenanceSnapshotForTesting(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool propagateFailure = false,
  }) async {
    _maintenanceStarted = true;
    await _applyMaintenanceDoc(
      snapshot,
      generation: _lifecycleGeneration,
      propagateFailure: propagateFailure,
    );
  }
}

@visibleForTesting
bool liveRemoteSyncGenerationIsCurrent({
  required int capturedGeneration,
  required int currentGeneration,
  required bool started,
  required bool paused,
}) => capturedGeneration == currentGeneration && started && !paused;

class _LiveRemoteListenerSpec {
  final _LiveRemoteMirrorKind kind;
  final String label;
  final Query<Map<String, dynamic>> query;

  const _LiveRemoteListenerSpec({
    required this.kind,
    required this.label,
    required this.query,
  });
}

enum _LiveRemoteMirrorKind { maintenanceTicket, workflow, lane, compliance }

@visibleForTesting
Duration? liveWorkflowProjectionReconciliationRetryDelay(int failureCount) {
  const delays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];
  if (failureCount < 1 || failureCount > delays.length) return null;
  return delays[failureCount - 1];
}

@visibleForTesting
bool shouldApplyLiveWorkflowProjection({
  required int? localVersion,
  required DateTime? localUpdatedAt,
  bool? localIsSynced,
  required int remoteVersion,
  required DateTime remoteUpdatedAt,
}) {
  if (localVersion == null || localUpdatedAt == null) return true;
  if (localIsSynced == false) return false;
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: localVersion,
    localUpdatedAt: localUpdatedAt,
    remoteVersion: remoteVersion,
    remoteUpdatedAt: remoteUpdatedAt,
  );
}
