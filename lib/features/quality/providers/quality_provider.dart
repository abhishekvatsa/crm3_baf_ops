import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/quality_warning.dart';
import '../data/quality_monitoring_population.dart';
export '../data/quality_monitoring_population.dart';
import '../services/quality_command_service.dart';
import 'quality_monitoring_submission_provider.dart';

const qualityWarningLiveWindowLimit = 500;

final qualityCommandServiceProvider = Provider<QualityCommandService>(
  (ref) => QualityCommandService(
    monitoringCreationFactory: () {
      if (kIsWeb) {
        throw const QualityCommandException(
          'Monitoring changes require the Android app with saved recovery support.',
          code: 'unsupported-platform',
        );
      }
      return ref.read(qualityMonitoringSubmissionControllerProvider);
    },
    monitoringClosureFactory: () {
      if (kIsWeb) {
        throw const QualityCommandException(
          'Monitoring changes require the Android app with saved recovery support.',
          code: 'unsupported-platform',
        );
      }
      return ref.read(qualityMonitoringSubmissionControllerProvider);
    },
  ),
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
  // Initial warning projections from pilot clients used ISO text while
  // governed decisions use Firestore timestamps. Ordering that mixed field
  // groups by value type rather than chronology. closedAt is server-authored
  // for every terminal warning, so it gives a stable bounded history window.
  final recent = warnings
      .orderBy('closedAt', descending: true)
      .limit(qualityWarningLiveWindowLimit)
      .snapshots()
      .map(_decodeQualityWarnings);
  return combineQualityWarningWindows(nonClosed, recent);
});

String linkedQualityAbnormalityId(QualityWarning warning) =>
    warning.sourceType == QualityWarningSourceType.issue
    ? 'issue_quality_${warning.sourceId}'
    : warning.sourceId;

/// Reads the exact canonical case used by the quality command transaction.
///
/// The warning feed is itself live Firestore data. Reading its linked RA state
/// from the device mirror could combine two different sync boundaries and hide
/// a newly required/completed state. This provider is mounted only for visible
/// lazy-list cards and is disposed as they leave the viewport.
final linkedQualityAbnormalityProvider = StreamProvider.autoDispose
    .family<ChargeAbnormality?, String>((ref, abnormalityId) {
      return FirebaseFirestore.instance
          .collection('charge_abnormalities')
          .doc(abnormalityId)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) return null;
            return ChargeAbnormality.fromMap(data, snapshot.id);
          });
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
  final byId = <String, QualityWarning>{};
  for (final warning in [...recent, ...nonClosed]) {
    final previous = byId[warning.warningId];
    if (previous == null || warning.version > previous.version) {
      byId[warning.warningId] = warning;
    } else if (warning.version == previous.version &&
        !listEquals(
          _warningRevisionEvidence(warning),
          _warningRevisionEvidence(previous),
        )) {
      throw StateError(
        'Quality warning ${warning.warningId} has contradictory revision '
        '${warning.version} evidence. Refresh to verify its current state.',
      );
    }
  }
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

// Compare persisted meaning, including attribution and governed asset identity.
// Object identity and timestamps alone cannot establish an equal revision.
List<Object?> _warningRevisionEvidence(QualityWarning warning) => [
  warning.warningId,
  warning.version,
  warning.sourceType,
  warning.sourceId,
  warning.sourceVersion,
  warning.sourceChargeNo,
  warning.sourceSummary,
  warning.sourceSeverity,
  warning.warningReason,
  warning.component,
  warning.status,
  warning.closureRequestReason,
  warning.closureRequestedAt,
  warning.closureRequestedByUid,
  warning.closureRequestedByName,
  warning.closedAt,
  warning.closedByUid,
  warning.closedByName,
  warning.closureDisposition,
  warning.decisionReason,
  warning.createdAt,
  warning.createdByUid,
  warning.createdByName,
  warning.updatedAt,
  warning.updatedByUid,
  warning.updatedByName,
  warning.affectedAssets.length,
  for (final asset in warning.affectedAssets)
    (
      asset.assetType,
      asset.assetNumber,
      asset.assetHierarchyReference?.encode(),
    ),
  warning.linkedReannealingChargeNos.length,
  ...warning.linkedReannealingChargeNos,
];

Stream<List<QualityWarning>> combineQualityWarningWindows(
  Stream<List<QualityWarning>> nonClosed,
  Stream<List<QualityWarning>> recent,
) {
  late StreamController<List<QualityWarning>> controller;
  StreamSubscription<List<QualityWarning>>? nonClosedSubscription;
  StreamSubscription<List<QualityWarning>>? recentSubscription;
  List<QualityWarning>? latestNonClosed;
  List<QualityWarning>? latestRecent;
  var observed = <String, QualityWarning>{};

  void emitWhenReady() {
    if (latestNonClosed == null || latestRecent == null) return;
    try {
      final merged = mergeQualityWarningWindows(
        latestNonClosed!,
        latestRecent!,
      );
      // Keep the greatest observed revision while an identity is in either
      // window, even if both listeners later deliver a delayed older snapshot.
      // Removing an identity from both windows also releases this memory.
      final previous = [
        for (final warning in merged)
          if (observed[warning.warningId] case final value?) value,
      ];
      final current = mergeQualityWarningWindows(merged, previous);
      observed = {for (final warning in current) warning.warningId: warning};
      controller.add(current);
    } catch (error, stack) {
      controller.addError(error, stack);
    }
  }

  controller = StreamController<List<QualityWarning>>(
    onListen: () {
      nonClosedSubscription = nonClosed.listen(
        (value) {
          latestNonClosed = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stack) {
          latestNonClosed = null;
          controller.addError(error, stack);
        },
      );
      recentSubscription = recent.listen(
        (value) {
          latestRecent = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stack) {
          latestRecent = null;
          controller.addError(error, stack);
        },
      );
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
      final requests = FirebaseFirestore.instance.collection(
        'quality_monitoring_requests',
      );
      // Read one authoritative population. The former current+legacy query
      // merge let delayed snapshots reintroduce an older row, and filtered
      // queries hid schema-3 rows whose visibility fields were malformed.
      // Decode the full snapshot tolerantly, then apply the effective window
      // locally so valid rows remain visible beside a damaged row.
      return combineQualityMonitoringWindows(
        requests
            .snapshots(includeMetadataChanges: true)
            .map(_decodeQualityMonitoringRequests),
        Stream<List<QualityMonitoringRequest>>.value(
          const <QualityMonitoringRequest>[],
        ),
      );
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
      ).map(
        (snapshot) => sortQualityMonitoringRequests(
          snapshot.docs.map(
            (doc) => QualityMonitoringRequest.fromMap(doc.data(), doc.id),
          ),
        ),
      );
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
) => decodeQualityMonitoringPopulation(
  snapshot.docs.map((doc) => (id: doc.id, data: doc.data())),
  isFromCache: snapshot.metadata.isFromCache,
  hasPendingWrites: snapshot.metadata.hasPendingWrites,
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

List<QualityMonitoringRequest> mergeQualityMonitoringWindows(
  List<QualityMonitoringRequest> current,
  List<QualityMonitoringRequest> legacy, {
  DateTime? now,
}) {
  final effectiveNow = (now ?? DateTime.now()).toUtc();
  final byId = <String, QualityMonitoringRequest>{};
  void absorb(QualityMonitoringRequest request) {
    final prior = byId[request.requestId];
    if (prior == null || request.version > prior.version) {
      byId[request.requestId] = request;
      return;
    }
    if (request.version == prior.version &&
        _monitoringBusinessEvidenceKey(request) !=
            _monitoringBusinessEvidenceKey(prior)) {
      throw StateError(
        'Contradictory quality-monitoring evidence at revision ${request.version} for ${request.requestId}.',
      );
    }
    // Equal-version visibility changes are allowed: archival is an
    // operational projection and deliberately does not advance the business
    // revision.
    if (request.version == prior.version &&
        request.visibilityState.index > prior.visibilityState.index) {
      byId[request.requestId] = request;
    }
  }

  for (final request in legacy) {
    absorb(request);
  }
  for (final request in current) {
    absorb(request);
  }
  return sortQualityMonitoringRequests(
    byId.values.where((request) {
      if (request.status == QualityMonitoringStatus.active) return true;
      return request.visibilityState ==
              QualityMonitoringVisibilityState.recent &&
          request.visibleUntil?.toUtc().isAfter(effectiveNow) == true;
    }),
  );
}

String _monitoringBusinessEvidenceKey(QualityMonitoringRequest request) =>
    jsonEncode({
      'requestId': request.requestId,
      'baseNumber': request.baseNumber,
      'baseAssetClassId': request.baseAssetClassId,
      'baseAssetInstanceId': request.baseAssetInstanceId,
      'baseAssetInstanceVersion': request.baseAssetInstanceVersion,
      'grade': request.grade,
      'cycleReference': request.cycleReference,
      'chargeNumbers': request.chargeNumbers,
      'reason': request.reason,
      'status': request.status.name,
      'closedAt': request.closedAt?.toUtc().toIso8601String(),
      'closedByUid': request.closedByUid,
      'closedByName': request.closedByName,
      'closeReason': request.closeReason,
      'createdAt': request.createdAt.toUtc().toIso8601String(),
      'createdByUid': request.createdByUid,
      'createdByName': request.createdByName,
      'updatedAt': request.updatedAt.toUtc().toIso8601String(),
      'updatedByUid': request.updatedByUid,
      'updatedByName': request.updatedByName,
      'version': request.version,
      'monitoringDisposition': request.monitoringDisposition,
      'originalMonitoringContext': request.originalMonitoringContext,
    });

Stream<List<QualityMonitoringRequest>> combineQualityMonitoringWindows(
  Stream<List<QualityMonitoringRequest>> current,
  Stream<List<QualityMonitoringRequest>> legacy, {
  DateTime Function()? clock,
}) {
  late StreamController<List<QualityMonitoringRequest>> controller;
  StreamSubscription<List<QualityMonitoringRequest>>? currentSubscription;
  StreamSubscription<List<QualityMonitoringRequest>>? legacySubscription;
  Timer? expiryTimer;
  List<QualityMonitoringRequest>? latestCurrent;
  List<QualityMonitoringRequest>? latestLegacy;
  final observed = <String, QualityMonitoringRequest>{};

  void retain(List<QualityMonitoringRequest> records) {
    for (final record in records) {
      final prior = observed[record.requestId];
      if (prior != null &&
          prior.version == record.version &&
          _monitoringBusinessEvidenceKey(prior) !=
              _monitoringBusinessEvidenceKey(record)) {
        throw StateError(
          'Contradictory monitoring evidence for ${record.requestId}.',
        );
      }
      if (prior == null ||
          record.version > prior.version ||
          (record.version == prior.version &&
              record.visibilityState.index > prior.visibilityState.index)) {
        observed[record.requestId] = record;
      }
    }
  }

  void emitWhenReady() {
    if (latestCurrent == null || latestLegacy == null || controller.isClosed) {
      return;
    }
    final now = (clock ?? DateTime.now)().toUtc();
    final List<QualityMonitoringRequest> merged;
    try {
      retain(latestLegacy!);
      retain(latestCurrent!);
      merged = mergeQualityMonitoringWindows(
        observed.values.toList(),
        const [],
        now: now,
      );
    } catch (error, stack) {
      expiryTimer?.cancel();
      if (!controller.isClosed) controller.addError(error, stack);
      return;
    }
    final currentPopulation = latestCurrent;
    controller.add(
      currentPopulation is QualityMonitoringPopulation
          ? currentPopulation.withRecords(
              merged,
              missingIds: observed.keys.where(
                (id) => !currentPopulation.any(
                  (row) =>
                      row.requestId == id &&
                      row.version >= observed[id]!.version,
                ),
              ),
            )
          : merged,
    );

    expiryTimer?.cancel();
    DateTime? nextExpiry;
    final byId = observed;
    for (final request in byId.values) {
      final visibleUntil = request.visibleUntil?.toUtc();
      if (request.status != QualityMonitoringStatus.closed ||
          request.visibilityState != QualityMonitoringVisibilityState.recent ||
          visibleUntil == null ||
          !visibleUntil.isAfter(now)) {
        continue;
      }
      if (nextExpiry == null || visibleUntil.isBefore(nextExpiry)) {
        nextExpiry = visibleUntil;
      }
    }
    if (nextExpiry != null) {
      expiryTimer = Timer(nextExpiry.difference(now), emitWhenReady);
    }
  }

  controller = StreamController<List<QualityMonitoringRequest>>(
    onListen: () {
      currentSubscription = current.listen(
        (value) {
          latestCurrent = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          latestCurrent = null;
          // Expiry must not turn stale monitoring evidence back into success.
          expiryTimer?.cancel();
          expiryTimer = null;
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      legacySubscription = legacy.listen(
        (value) {
          latestLegacy = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          latestLegacy = null;
          // Expiry must not turn stale monitoring evidence back into success.
          expiryTimer?.cancel();
          expiryTimer = null;
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
    },
    onCancel: () async {
      expiryTimer?.cancel();
      await currentSubscription?.cancel();
      await legacySubscription?.cancel();
    },
  );
  return controller.stream;
}

int _warningStatusRank(QualityWarningStatus status) => switch (status) {
  QualityWarningStatus.closureRequested => 0,
  QualityWarningStatus.open => 1,
  QualityWarningStatus.closed => 2,
};
