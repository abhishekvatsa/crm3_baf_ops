part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// PLANNED MAINTENANCE (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullPlanned on GlobalPullService {
  Future<void> _pullPlanned(DateTime? lastSync) async {
    await _pullTemplateGovernance(lastSync);
    await _pullTemplates(lastSync);
    await _pullExecutions(lastSync);
    await _pullJobDiaryEntries(lastSync);
    await _pullJobModules(lastSync);
  }

  Future<void> _pullTemplates(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedTemplates(
        since: lastSync,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final templates = result.records;
      _observeFetchedRemoteRecords(templates);
      startAfter = result.lastDoc;

      if (templates.isEmpty) break;

      final inserts = <JobTemplate>[];
      final updates = <JobTemplate>[];
      final tombstones = <JobTemplate>[];

      for (final remote in templates) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _plannedRepo.getTemplateByFirestoreId(
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
              _logPullConflict('template', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _plannedRepo.applyTombstoneFromTemplateRemote(
          remote,
        );
        _recordTombstoneApplyResult('job template', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _plannedRepo.insertTemplateFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _plannedRepo.updateTemplateFromRemote(remote);
        lastUpdated++;
      }

      if (templates.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullExecutions(DateTime? lastSync) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedExecutions(
        since: lastSync,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final executions = result.records;
      _observeFetchedRemoteRecords(executions);
      startAfter = result.lastDoc;

      if (executions.isEmpty) break;

      final inserts = <JobExecution>[];
      final updates = <JobExecution>[];
      final tombstones = <JobExecution>[];

      for (final remote in executions) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _plannedRepo.getExecutionByFirestoreId(
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
              _logPullConflict('execution', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Execution pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _plannedRepo.applyTombstoneFromExecutionRemote(
          remote,
        );
        _recordTombstoneApplyResult('job execution', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _plannedRepo.insertExecutionFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _plannedRepo.updateExecutionFromRemote(remote);
        lastUpdated++;
      }

      if (executions.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
