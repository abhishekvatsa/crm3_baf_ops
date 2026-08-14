import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quality_warning.dart';
import '../services/quality_command_service.dart';

const qualityWarningLiveWindowLimit = 500;
const qualityMonitoringLiveWindowLimit = 250;

final qualityCommandServiceProvider = Provider<QualityCommandService>(
  (ref) => QualityCommandService(),
);

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
          .orderBy('updatedAt', descending: true)
          .limit(qualityMonitoringLiveWindowLimit)
          .snapshots()
          .map((snapshot) {
            final requests =
                snapshot.docs
                    .map(
                      (document) => QualityMonitoringRequest.fromMap(
                        document.data(),
                        document.id,
                      ),
                    )
                    .toList();
            requests.sort((left, right) {
              final status = left.status.index.compareTo(right.status.index);
              if (status != 0) return status;
              return right.createdAt.compareTo(left.createdAt);
            });
            return List<QualityMonitoringRequest>.unmodifiable(requests);
          });
    });

int _warningStatusRank(QualityWarningStatus status) => switch (status) {
  QualityWarningStatus.closureRequested => 0,
  QualityWarningStatus.open => 1,
  QualityWarningStatus.closed => 2,
};
