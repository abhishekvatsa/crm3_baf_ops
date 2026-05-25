part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// WATERMARK HELPERS
// ─────────────────────────────────────────────────────────────

extension _GlobalPullWatermark on GlobalPullService {
  DateTime? _nextGlobalPullToken({DateTime? previousToken}) {
    final maxFetched = _maxFetchedRemoteUpdatedAt;
    if (maxFetched == null) return previousToken;

    final candidate = maxFetched.subtract(
      GlobalPullService._pullTokenSafetyMargin,
    );
    if (previousToken != null && candidate.isBefore(previousToken)) {
      return previousToken;
    }
    return candidate;
  }

  void _observeFetchedRemoteRecords(Iterable<dynamic> records) {
    for (final record in records) {
      _observeFetchedRemoteUpdatedAt(_readUpdatedAt(record));
    }
  }

  void _observeFetchedRemoteUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return;
    final current = _maxFetchedRemoteUpdatedAt;
    if (current == null || updatedAt.isAfter(current)) {
      _maxFetchedRemoteUpdatedAt = updatedAt;
    }
  }

  DateTime? _readUpdatedAt(dynamic record) {
    try {
      final value = record.updatedAt;
      if (value is DateTime) return value;
    } catch (_) {
      // Best-effort watermark tracking; malformed records are handled by the
      // entity-specific processing paths below.
    }
    return null;
  }
}
