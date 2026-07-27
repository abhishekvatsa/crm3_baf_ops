part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// MAINTENANCE (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullMaintenance on GlobalPullService {
  Future<void> _pullMaintenance(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreMaintenance.getUpdatedTickets(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final remoteRecords = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (remoteRecords.isEmpty) break;

      final inserts = <MaintenanceRecord>[];
      final updates = <MaintenanceRecord>[];
      final tombstones = <MaintenanceRecord>[];

      for (final remote in remoteRecords) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _maintenanceRepo.getByFirestoreId(
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
              _logPullConflict('ticket', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Maintenance pull processing error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _maintenanceRepo
            .applyTombstoneFromMaintenanceRemote(remote);
        _recordTombstoneApplyResult('maintenance ticket', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _maintenanceRepo.insertFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _maintenanceRepo.updateFromRemote(remote);
        lastUpdated++;
      }

      if (remoteRecords.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
