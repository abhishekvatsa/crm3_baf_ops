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

Stream<T> admitActorSessionSnapshots<T>(
  Stream<T> snapshots, {
  required ActorSessionCacheTrust trust,
  required String actorUid,
  required String queryKey,
  required bool Function(T snapshot) isFromCache,
  required bool Function(T snapshot) hasPendingWrites,
}) {
  return snapshots.where(
    (snapshot) => trust.acceptSnapshot(
      actorUid: actorUid,
      queryKey: queryKey,
      isFromCache: isFromCache(snapshot),
      hasPendingWrites: hasPendingWrites(snapshot),
    ),
  );
}
