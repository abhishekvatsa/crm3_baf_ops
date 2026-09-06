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

      for (final remote in modules) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _jobModuleRepo.applyTombstoneFromRemote(
              remote,
            );
            _recordTombstoneApplyResult('job module', remote, result);
            continue;
          }
          final result = await _jobModuleRepo.applyModuleFromRemote(remote);
          _recordRemoteApplyResult('job module', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Job module pull error: $e');
        }
      }

      if (modules.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
