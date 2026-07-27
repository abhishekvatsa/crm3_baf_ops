part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// JOB MODULES (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullJobModules on GlobalPullService {
  Future<void> _pullJobModules(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreJobModule.getUpdatedModules(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final modules = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (modules.isEmpty) break;

      final inserts = <JobModuleInstance>[];
      final updates = <JobModuleInstance>[];
      final tombstones = <JobModuleInstance>[];

      for (final remote in modules) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _jobModuleRepo.getModuleByFirestoreId(
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
              _logPullConflict('job module', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job module pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _jobModuleRepo.applyTombstoneFromRemote(remote);
        _recordTombstoneApplyResult('job module', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _jobModuleRepo.insertModuleFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _jobModuleRepo.updateModuleFromRemote(remote);
        lastUpdated++;
      }

      if (modules.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
