import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/quality_warning.dart';
import '../services/quality_command_service.dart';

const qualityWarningLiveWindowLimit = 500;

final qualityCommandServiceProvider = Provider<QualityCommandService>(
  (ref) => QualityCommandService(),
);

final qualityReportCacheTrustProvider = Provider<ActorSessionCacheTrust>((ref) {
  final trust = ActorSessionCacheTrust();

  void observeAuthority(AsyncValue<AppUser?> authority) {
    if (authority.isLoading || authority.hasError) {
      trust.observeActor(null);
      return;
    }
    final actor = authority.value;
    trust.observeActor(
      actor != null && actor.canViewReports ? actor.uid : null,
    );
  }

  observeAuthority(ref.read(currentAppUserProvider));
  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (_, next) {
    observeAuthority(next);
  });
  return trust;
});

final qualityWarningsProvider = StreamProvider<List<QualityWarning>>((ref) {
  final warnings = FirebaseFirestore.instance.collection('quality_warnings');
  final nonClosed = warnings
      .where(
        'status',
        whereIn: [
          QualityWarningStatus.open.name,
          QualityWarningStatus.closureRequested.name,
        ],
      )
      .snapshots()
      .map(_decodeQualityWarnings);
  final recent = warnings
      .orderBy('updatedAt', descending: true)
      .limit(qualityWarningLiveWindowLimit)
      .snapshots()
      .map(_decodeQualityWarnings);
  return _combineQualityWarningWindows(nonClosed, recent);
});

/// Complete quality-warning population for period-bound reports.
///
/// The interactive workspace intentionally combines active records with a
/// bounded recent window. Reports cannot use that window because an older
/// closed warning may still fall inside a historical reporting period.
final qualityWarningsForReportsProvider = StreamProvider.autoDispose
    .family<List<QualityWarning>, String>((ref, actorUid) {
      _requireQualityReportActor(ref.watch(currentAppUserProvider), actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('quality_warnings')
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: ref.watch(qualityReportCacheTrustProvider)
          ..observeActor(actorUid),
        actorUid: actorUid,
        queryKey: 'quality-warnings:reports',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(_decodeQualityWarnings);
    });

List<QualityWarning> _decodeQualityWarnings(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) => snapshot.docs
    .map((document) => QualityWarning.fromMap(document.data(), document.id))
    .toList(growable: false);

List<QualityWarning> mergeQualityWarningWindows(
  List<QualityWarning> nonClosed,
  List<QualityWarning> recent,
) {
  final byId = <String, QualityWarning>{
    for (final warning in recent) warning.warningId: warning,
    for (final warning in nonClosed) warning.warningId: warning,
  };
  final warnings = byId.values.toList();
  warnings.sort((left, right) {
    final status = _warningStatusRank(
      left.status,
    ).compareTo(_warningStatusRank(right.status));
    if (status != 0) return status;
    return right.updatedAt.compareTo(left.updatedAt);
  });
  return List<QualityWarning>.unmodifiable(warnings);
}

Stream<List<QualityWarning>> _combineQualityWarningWindows(
  Stream<List<QualityWarning>> nonClosed,
  Stream<List<QualityWarning>> recent,
) {
  late StreamController<List<QualityWarning>> controller;
  StreamSubscription<List<QualityWarning>>? nonClosedSubscription;
  StreamSubscription<List<QualityWarning>>? recentSubscription;
  List<QualityWarning>? latestNonClosed;
  List<QualityWarning>? latestRecent;

  void emitWhenReady() {
    if (latestNonClosed == null || latestRecent == null) return;
    controller.add(mergeQualityWarningWindows(latestNonClosed!, latestRecent!));
  }

  controller = StreamController<List<QualityWarning>>(
    onListen: () {
      nonClosedSubscription = nonClosed.listen((value) {
        latestNonClosed = value;
        emitWhenReady();
      }, onError: controller.addError);
      recentSubscription = recent.listen((value) {
        latestRecent = value;
        emitWhenReady();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await nonClosedSubscription?.cancel();
      await recentSubscription?.cancel();
    },
  );
  return controller.stream;
}

final qualityMonitoringRequestsProvider =
    StreamProvider<List<QualityMonitoringRequest>>((ref) {
      return FirebaseFirestore.instance
          .collection('quality_monitoring_requests')
          .where(
            'visibilityState',
            whereIn: <String>[
              QualityMonitoringVisibilityState.active.name,
              QualityMonitoringVisibilityState.recent.name,
            ],
          )
          .snapshots()
          .map(_decodeQualityMonitoringRequests);
    });

/// Complete quality-monitoring population for date- and asset-bound reports.
///
/// The interactive list intentionally keeps a recent window. Reports must
/// filter only after receiving every request because an old active request or
/// a closed request overlapping a historical period remains decision-relevant.
final qualityMonitoringRequestsForReportsProvider = StreamProvider.autoDispose
    .family<List<QualityMonitoringRequest>, String>((ref, actorUid) {
      _requireQualityReportActor(ref.watch(currentAppUserProvider), actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('quality_monitoring_requests')
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: ref.watch(qualityReportCacheTrustProvider)
          ..observeActor(actorUid),
        actorUid: actorUid,
        queryKey: 'quality-monitoring:reports',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(_decodeQualityMonitoringRequests);
    });

void _requireQualityReportActor(
  AsyncValue<AppUser?> actorAsync,
  String actorUid,
) {
  if (actorAsync.isLoading) {
    throw StateError('Quality-report access is still being verified.');
  }
  if (actorAsync.hasError) {
    throw StateError('Quality-report access could not be verified.');
  }
  final actor = actorAsync.value;
  if (actor == null ||
      !actor.canViewReports ||
      actor.uid != actorUid ||
      actorUid.trim().isEmpty) {
    throw StateError('Approved quality-report access is required.');
  }
}

List<QualityMonitoringRequest> _decodeQualityMonitoringRequests(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) => sortQualityMonitoringRequests(
  snapshot.docs
      .map(
        (document) =>
            QualityMonitoringRequest.fromMap(document.data(), document.id),
      )
      .toList(growable: false),
);

List<QualityMonitoringRequest> sortQualityMonitoringRequests(
  Iterable<QualityMonitoringRequest> source,
) {
  final requests = source.toList();
  requests.sort((left, right) {
    final status = left.status.index.compareTo(right.status.index);
    if (status != 0) return status;
    return right.createdAt.compareTo(left.createdAt);
  });
  return List<QualityMonitoringRequest>.unmodifiable(requests);
}

int _warningStatusRank(QualityWarningStatus status) => switch (status) {
  QualityWarningStatus.closureRequested => 0,
  QualityWarningStatus.open => 1,
  QualityWarningStatus.closed => 2,
};
