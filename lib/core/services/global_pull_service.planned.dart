part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// PLANNED MAINTENANCE (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullPlanned on GlobalPullService {
  Future<void> _pullTemplates(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedTemplates(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final templates = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (templates.isEmpty) break;

      for (final remote in templates) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _plannedRepo.applyTombstoneFromTemplateRemote(
              remote,
            );
            _recordTombstoneApplyResult('job template', remote, result);
            continue;
          }
          final result = await _plannedRepo.applyTemplateFromRemote(remote);
          _recordRemoteApplyResult('job template', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template pull error: $e');
        }
      }

      if (templates.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullExecutions(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestorePlanned.getUpdatedExecutions(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final executions = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (executions.isEmpty) break;

      for (final remote in executions) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _plannedRepo.applyTombstoneFromExecutionRemote(
              remote,
            );
            _recordTombstoneApplyResult('job execution', remote, result);
            continue;
          }
          final result = await _plannedRepo.applyExecutionFromRemote(remote);
          _recordRemoteApplyResult('job execution', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Execution pull error: $e');
        }
      }

      if (executions.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
