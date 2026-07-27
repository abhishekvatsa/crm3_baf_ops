part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// ABNORMALITIES (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullAbnormalities on GlobalPullService {
  Future<void> _pullAbnormalityTypes(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreAbnormality.getUpdatedTypes(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final records = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (records.isEmpty) break;

      final inserts = <AbnormalityType>[];
      final updates = <AbnormalityType>[];
      final tombstones = <AbnormalityType>[];

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _abnormalityRepo.getTypeByFirestoreId(
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
              _logPullConflict('abnormality type', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Abnormality type pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _abnormalityRepo.applyTombstoneFromTypeRemote(
          remote,
        );
        _recordTombstoneApplyResult('abnormality type', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _abnormalityRepo.insertTypeFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _abnormalityRepo.updateTypeFromRemote(remote);
        lastUpdated++;
      }

      if (records.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullChargeAbnormalities(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreAbnormality.getUpdatedAbnormalities(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final records = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (records.isEmpty) break;

      final inserts = <ChargeAbnormality>[];
      final updates = <ChargeAbnormality>[];
      final tombstones = <ChargeAbnormality>[];

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _abnormalityRepo.getAbnormalityByFirestoreId(
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
              _logPullConflict('charge abnormality', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Charge abnormality pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _abnormalityRepo
            .applyTombstoneFromAbnormalityRemote(remote);
        _recordTombstoneApplyResult('charge abnormality', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _abnormalityRepo.insertAbnormalityFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _abnormalityRepo.updateAbnormalityFromRemote(remote);
        lastUpdated++;
      }

      if (records.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
