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
  return FirebaseFirestore.instance
      .collection('quality_warnings')
      .orderBy('updatedAt', descending: true)
      .limit(qualityWarningLiveWindowLimit)
      .snapshots()
      .map((snapshot) {
        final warnings =
            snapshot.docs
                .map(
                  (document) =>
                      QualityWarning.fromMap(document.data(), document.id),
                )
                .toList();
        warnings.sort((left, right) {
          final status = _warningStatusRank(
            left.status,
          ).compareTo(_warningStatusRank(right.status));
          if (status != 0) return status;
          return right.updatedAt.compareTo(left.updatedAt);
        });
        return List<QualityWarning>.unmodifiable(warnings);
      });
});

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
