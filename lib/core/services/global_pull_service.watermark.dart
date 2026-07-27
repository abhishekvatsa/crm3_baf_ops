part of 'global_pull_service.dart';

extension _GlobalPullServerWindow on GlobalPullService {
  void _validateFetchedServerBoundary(
    DocumentSnapshot? document,
    DateTime through,
  ) {
    if (document == null) return;
    final data = document.data();
    if (data is! Map<String, dynamic>) {
      throw const GlobalPullProtocolException(
        'A global pull page boundary is not a document map.',
        reasonCode: 'page-boundary-not-map',
      );
    }
    final value = data[globalPullServerUpdatedAtField];
    if (value is! Timestamp) {
      throw const GlobalPullProtocolException(
        'A global pull page boundary has no valid server timestamp.',
        reasonCode: 'page-boundary-server-timestamp-invalid',
      );
    }
    if (value.toDate().toUtc().isAfter(through.toUtc())) {
      throw const GlobalPullProtocolException(
        'A global pull page escaped its authoritative server window.',
        reasonCode: 'page-boundary-after-server-anchor',
      );
    }
  }
}
