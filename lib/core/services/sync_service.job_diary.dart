part of 'sync_service.dart';

extension _SyncServiceJobDiary on SyncService {
  Future<void> _syncJobDiaryEntries() async {
    final unsynced = await _jobDiaryRepo.getUnsyncedEntries();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_diary_entry',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreJobDiary.getEntriesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobDiaryEntry>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_diary_entry',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for job diary entry ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for job diary entry ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'job diary entry ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (remote != null &&
            !record.isDeleted &&
            !remote.isDeleted &&
            syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _jobDiaryRepo.applyTombstoneFromRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for job diary entry ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for job diary entry ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'planned_job_diary_entry',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local job diary entry ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreJobDiary.batchUpsertEntries(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'job_diary_entry',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Job diary entry batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _jobDiaryRepo.markEntriesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }
}
