/// Tracks which exact remote queries have been server-confirmed for the
/// continuous approved actor session.
final class ActorSessionCacheTrust {
  String? _actorUid;
  final Set<String> _serverConfirmedQueries = <String>{};

  void observeActor(String? actorUid) {
    final normalized = actorUid?.trim();
    final nextActor =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (nextActor == _actorUid) return;
    _actorUid = nextActor;
    _serverConfirmedQueries.clear();
  }

  bool acceptSnapshot({
    required String actorUid,
    required String queryKey,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    final normalizedActor = actorUid.trim();
    final normalizedQuery = queryKey.trim();
    if (normalizedActor.isEmpty ||
        normalizedQuery.isEmpty ||
        normalizedActor != _actorUid) {
      return false;
    }
    if (hasPendingWrites) return false;
    if (!isFromCache) {
      _serverConfirmedQueries.add(normalizedQuery);
      return true;
    }
    return _serverConfirmedQueries.contains(normalizedQuery);
  }
}

final class ActorSessionSnapshotTrustException implements Exception {
  const ActorSessionSnapshotTrustException();

  @override
  String toString() =>
      'Data is not yet server-confirmed for this approved session. Reconnect and retry.';
}

Stream<T> admitActorSessionSnapshots<T>(
  Stream<T> snapshots, {
  required ActorSessionCacheTrust trust,
  required String actorUid,
  required String queryKey,
  required bool Function(T snapshot) isFromCache,
  required bool Function(T snapshot) hasPendingWrites,
}) {
  var hasAdmittedSnapshot = false;
  var initialRejectionSurfaced = false;
  return snapshots
      .map((snapshot) {
        final accepted = trust.acceptSnapshot(
          actorUid: actorUid,
          queryKey: queryKey,
          isFromCache: isFromCache(snapshot),
          hasPendingWrites: hasPendingWrites(snapshot),
        );
        if (accepted) {
          hasAdmittedSnapshot = true;
        } else if (!hasAdmittedSnapshot && !initialRejectionSurfaced) {
          initialRejectionSurfaced = true;
          throw const ActorSessionSnapshotTrustException();
        }
        return (accepted: accepted, snapshot: snapshot);
      })
      .where((entry) => entry.accepted)
      .map((entry) => entry.snapshot);
}
