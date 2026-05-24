// FILE: lib/core/services/sync_remote_freshness_policy.dart

/// Version-first remote freshness policy used by push-sync conflict checks.
///
/// This intentionally treats [remoteVersion] as the primary authority. A newer
/// remote version wins even if timestamps drift, while a lower remote version is
/// never considered newer merely because its timestamp is later. For equal
/// versions, [remoteUpdatedAt] is used as the tie-breaker.
///
/// The equal-version/newer-remote-time branch is deliberately conservative for
/// safety-critical sync paths: it forces conflict/reconciliation rather than
/// silently overwriting a remote document that changed after the local snapshot.
class SyncRemoteFreshnessPolicy {
  const SyncRemoteFreshnessPolicy._();

  static bool isRemoteNewer({
    required int localVersion,
    required DateTime localUpdatedAt,
    required int remoteVersion,
    required DateTime remoteUpdatedAt,
  }) {
    if (remoteVersion > localVersion) {
      return true;
    }

    if (remoteVersion < localVersion) {
      return false;
    }

    return remoteUpdatedAt.isAfter(localUpdatedAt);
  }
}
