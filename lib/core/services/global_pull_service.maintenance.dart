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

      if (result.decodeErrorCount > 0) {
        lastSkipped += result.decodeErrorCount;
        _hadRecordProcessingError = true;
        debugPrint(
          'Maintenance pull quarantined ${result.decodeErrorCount} malformed '
          'document(s); this domain cursor will not advance.',
        );
      }

      if (result.sourceDocumentCount == 0) break;

      for (final remote in remoteRecords) {
        try {
          if (remote.firestoreId == null) continue;

          if (remote.isDeleted) {
            final tombstoneResult = await _maintenanceRepo
                .applyTombstoneFromMaintenanceRemote(remote);
            _recordTombstoneApplyResult(
              'maintenance ticket',
              remote,
              tombstoneResult,
            );
            continue;
          }

          final applyResult = await _maintenanceRepo
              .applyMaintenanceRecordFromRemote(remote);
          _recordRemoteApplyResult('maintenance ticket', remote, applyResult);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Maintenance pull processing error: $e');
        }
      }

      if (result.sourceDocumentCount < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
