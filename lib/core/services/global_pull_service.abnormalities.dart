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

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _abnormalityRepo.applyTombstoneFromTypeRemote(
              remote,
            );
            _recordTombstoneApplyResult('abnormality type', remote, result);
            continue;
          }
          final result = await _abnormalityRepo.applyTypeFromRemote(remote);
          _recordRemoteApplyResult('abnormality type', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Abnormality type pull error: $e');
        }
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

      for (final remote in records) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _abnormalityRepo
                .applyTombstoneFromAbnormalityRemote(remote);
            _recordTombstoneApplyResult('charge abnormality', remote, result);
            continue;
          }
          final result = await _abnormalityRepo.applyAbnormalityFromRemote(
            remote,
          );
          _recordRemoteApplyResult('charge abnormality', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Charge abnormality pull error: $e');
        }
      }

      if (records.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
