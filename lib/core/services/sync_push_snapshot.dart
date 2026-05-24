class SyncPushSnapshot {
  final int id;
  final int version;
  final DateTime updatedAt;

  const SyncPushSnapshot({
    required this.id,
    required this.version,
    required this.updatedAt,
  });

  bool matches({
    required int currentVersion,
    required DateTime currentUpdatedAt,
  }) {
    return currentVersion == version &&
        currentUpdatedAt.isAtSameMomentAs(updatedAt);
  }
}
