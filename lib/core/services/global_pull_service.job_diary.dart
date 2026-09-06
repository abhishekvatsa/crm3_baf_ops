part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// JOB DIARY (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullJobDiary on GlobalPullService {
  Future<void> _pullJobDiaryEntries(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreJobDiary.getUpdatedEntries(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final entries = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (entries.isEmpty) break;

      for (final remote in entries) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _jobDiaryRepo.applyTombstoneFromRemote(remote);
            _recordTombstoneApplyResult('job diary entry', remote, result);
            continue;
          }
          final result = await _jobDiaryRepo.applyEntryFromRemote(remote);
          _recordRemoteApplyResult('job diary entry', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job diary pull error: $e');
        }
      }

      if (entries.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
