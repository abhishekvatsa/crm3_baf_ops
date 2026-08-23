// FILE: lib/core/services/live_remote_sync_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../features/auth/data/user_model.dart';
import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/maintenance/data/remote_maintenance_reader.dart';
import 'app_logger.dart';
import 'sync_remote_freshness_policy.dart';

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
// Current rollout scope: open, non-deleted maintenance tickets, scoped by
// the signed-in actor wherever that can be done without changing UI authority.
// Supervisory/Admin/SI users receive all open tickets. Non-broad actors receive
// a smaller live mirror: their own raised tickets, their discipline-routed
// tickets, and critical tickets when their role is senior/discipline authority.
// Full SyncCoordinator/GlobalPullService remains the source of convergence.

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
      maintenanceScopeLabel:
          clearMaintenanceScopeLabel
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
    maintenanceState:
        kIsWeb
            ? LiveRemoteSyncConnectionState.disabled
            : LiveRemoteSyncConnectionState.disconnected,
  );
});

typedef LiveRemoteSyncProviderReader =
    T Function<T>(ProviderListenable<T> provider);

class LiveRemoteSyncService {
  final Isar _isar;
  final LiveRemoteSyncProviderReader _read;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _maintenanceSubs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  LiveMaintenanceMirrorScope? _maintenanceScope;
  bool _maintenanceStarted = false;
  bool _pausedForLifecycle = false;

  LiveRemoteSyncService(this._isar, this._read);

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
    _cancelMaintenanceSubscriptions();

    _setHealth(
      _health.copyWith(
        maintenanceState:
            kIsWeb
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

    final listenerSpecs = _maintenanceListenerSpecs(scope);
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
    _setHealth(
      _health.copyWith(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
        startedAt: DateTime.now(),
        clearPausedAt: true,
        clearLastError: true,
        maintenanceScopeLabel: scope.label,
        listenerCount: listenerSpecs.length,
      ),
    );

    unawaited(
      AppLogger.setCustomKeys({
        'live_maintenance_state': 'listening',
        'live_maintenance_scope': scope.label,
        'live_maintenance_listener_count': listenerSpecs.length,
      }),
    );

    for (final spec in listenerSpecs) {
      final sub = spec.query.snapshots().listen(
        _handleMaintenanceSnapshot,
        onError: (Object error, StackTrace stackTrace) {
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
          if (_pausedForLifecycle) return;
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
  }

  List<_MaintenanceListenerSpec> _maintenanceListenerSpecs(
    LiveMaintenanceMirrorScope scope,
  ) {
    final base = FirebaseFirestore.instance
        .collection('maintenance_records')
        .where('isDeleted', isEqualTo: false)
        .where('isResolved', isEqualTo: false);

    if (scope.listenToAllOpenTickets) {
      return <_MaintenanceListenerSpec>[
        _MaintenanceListenerSpec(label: 'all_open', query: base),
      ];
    }

    final specs = <_MaintenanceListenerSpec>[];

    if (scope.includeOwnLoggedTickets && scope.actorUid.trim().isNotEmpty) {
      specs.add(
        _MaintenanceListenerSpec(
          label: 'own_logged',
          query: base.where('loggedByUid', isEqualTo: scope.actorUid),
        ),
      );
    }

    for (final routedTo in scope.routedTo) {
      specs.addAll(<_MaintenanceListenerSpec>[
        _MaintenanceListenerSpec(
          label: 'lane_${routedTo.name}',
          query: base.where('issueAssignedLanes', arrayContains: routedTo.name),
        ),
        _MaintenanceListenerSpec(
          label: 'legacy_routed_${routedTo.name}',
          query: base.where('routedTo', isEqualTo: routedTo.name),
        ),
      ]);
    }

    if (scope.includeCriticalTickets) {
      specs.add(
        _MaintenanceListenerSpec(
          label: 'critical',
          query: base.where('isCritical', isEqualTo: true),
        ),
      );
    }

    return specs;
  }

  void _cancelMaintenanceSubscriptions() {
    final subs =
        List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>.from(
          _maintenanceSubs,
        );
    _maintenanceSubs.clear();

    for (final sub in subs) {
      unawaited(sub.cancel());
    }
  }

  void _handleMaintenanceSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
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
          unawaited(_applyMaintenanceDoc(change.doc));
          break;
        case DocumentChangeType.removed:
          _setHealth(
            _health.copyWith(removedEventCount: _health.removedEventCount + 1),
          );
          // A removed change from this query usually means the ticket was
          // resolved, soft-deleted, or moved outside the scoped query. Fetch the
          // document directly to apply its full current state rather than
          // guessing from query removal alone.
          unawaited(_applyRemovedMaintenanceDoc(change.doc.reference));
          break;
      }
    }
  }

  Future<void> _applyRemovedMaintenanceDoc(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      final doc = await reference.get();
      if (!doc.exists) return;
      await _applyMaintenanceDoc(doc);
    } catch (error, stackTrace) {
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
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;

    try {
      final remote = _mapTicket(doc, data);
      if (remote.firestoreId == null) return;
      var applied = false;
      var skippedUnsynced = false;

      await _isar.writeTxn(() async {
        final local =
            await _isar.maintenanceRecords
                .filter()
                .firestoreIdEqualTo(remote.firestoreId!)
                .findFirst();

        if (local == null) {
          if (remote.isDeleted) return;
          remote.isSynced = true;
          await _isar.maintenanceRecords.put(remote);
          applied = true;
          return;
        }

        final decision = _remoteDecision(local, remote);
        if (decision == _RemoteApplyDecision.skipLocalUnsynced) {
          skippedUnsynced = true;
          return;
        }
        if (decision == _RemoteApplyDecision.skip) return;

        _copyRemoteTicketIntoLocal(remote, local);
        await _isar.maintenanceRecords.put(local);
        applied = true;
      });

      if (applied) {
        _setHealth(
          _health.copyWith(
            maintenanceState: LiveRemoteSyncConnectionState.listening,
            lastAppliedAt: DateTime.now(),
            appliedCount: _health.appliedCount + 1,
            clearLastError: true,
          ),
        );
      } else if (skippedUnsynced) {
        _setHealth(
          _health.copyWith(
            skippedUnsyncedLocalCount: _health.skippedUnsyncedLocalCount + 1,
          ),
        );
      }
    } catch (error, stackTrace) {
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

  _RemoteApplyDecision _remoteDecision(
    MaintenanceRecord local,
    MaintenanceRecord remote,
  ) {
    final remoteNewer = _isRemoteNewerByPolicy(local, remote);

    final localNewer = local.updatedAt.isAfter(remote.updatedAt);

    // Protect local offline/operator edits. The full SyncCoordinator/GlobalPull
    // path will reconcile later and can log conflicts. The live listener should
    // not erase local unsynced work.
    if (!local.isSynced) return _RemoteApplyDecision.skipLocalUnsynced;

    if (remote.isDeleted) {
      return (remoteNewer || !local.isDeleted)
          ? _RemoteApplyDecision.apply
          : _RemoteApplyDecision.skip;
    }

    if (localNewer && !remoteNewer) return _RemoteApplyDecision.skip;

    return (remoteNewer || local.version != remote.version)
        ? _RemoteApplyDecision.apply
        : _RemoteApplyDecision.skip;
  }

  void _copyRemoteTicketIntoLocal(
    MaintenanceRecord remote,
    MaintenanceRecord local,
  ) {
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
      ..isCritical = remote.isCritical
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
      ..loggedByUid = remote.loggedByUid
      ..loggedByName = remote.loggedByName
      ..reportedBy = remote.reportedBy
      ..acknowledgedByUid = remote.acknowledgedByUid
      ..acknowledgedByName = remote.acknowledgedByName
      ..acknowledgedAt = remote.acknowledgedAt
      ..closedByUid = remote.closedByUid
      ..closedByName = remote.closedByName
      ..teamsInvolved = List<String>.from(remote.teamsInvolved)
      ..performedBy = remote.performedBy
      ..remarks = remote.remarks
      ..startDate = remote.startDate
      ..endDate = remote.endDate
      ..downtimeHours = remote.downtimeHours
      ..chargeNoAtEvent = remote.chargeNoAtEvent
      ..createdAt = remote.createdAt
      ..updatedAt = remote.updatedAt
      ..metadataJson = remote.metadataJson
      ..actionsJson = remote.actionsJson
      ..resolutionHistoryJson = remote.resolutionHistoryJson
      ..isDeleted = remote.isDeleted
      ..deletedAt = remote.deletedAt
      ..deletedByUid = remote.deletedByUid
      ..deletedByName = remote.deletedByName
      ..deleteReason = remote.deleteReason
      ..isSynced = true;
  }

  MaintenanceRecord _mapTicket(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> d,
  ) => readRemoteMaintenanceRecord(d, documentId: doc.id);

  LiveRemoteSyncHealth get _health => _read(liveRemoteSyncHealthProvider);

  void _setHealth(LiveRemoteSyncHealth health) {
    _read(liveRemoteSyncHealthProvider.notifier).state = health;
  }
}

class _MaintenanceListenerSpec {
  final String label;
  final Query<Map<String, dynamic>> query;

  const _MaintenanceListenerSpec({required this.label, required this.query});
}

enum _RemoteApplyDecision { apply, skip, skipLocalUnsynced }
