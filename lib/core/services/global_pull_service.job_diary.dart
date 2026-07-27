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

      final inserts = <JobDiaryEntry>[];
      final updates = <JobDiaryEntry>[];
      final tombstones = <JobDiaryEntry>[];

      for (final remote in entries) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _jobDiaryRepo.getEntryByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) {
              tombstones.add(remote);
            }
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('job diary entry', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job diary pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _jobDiaryRepo.applyTombstoneFromRemote(remote);
        _recordTombstoneApplyResult('job diary entry', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _jobDiaryRepo.insertEntryFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _jobDiaryRepo.updateEntryFromRemote(remote);
        lastUpdated++;
      }

      if (entries.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
