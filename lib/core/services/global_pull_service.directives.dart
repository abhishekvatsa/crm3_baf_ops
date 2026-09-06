part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// DIRECTIVES (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullDirectives on GlobalPullService {
  Future<void> _pullDirectives(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreDirective.getUpdatedDirectives(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final directives = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (directives.isEmpty) break;

      for (final remote in directives) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _directiveRepo
                .applyTombstoneFromDirectiveRemote(remote);
            _recordTombstoneApplyResult(
              'operational directive',
              remote,
              result,
            );
            continue;
          }
          final result = await _directiveRepo.applyDirectiveFromRemote(remote);
          _recordRemoteApplyResult('operational directive', remote, result);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Directive pull error: $e');
        }
      }

      if (directives.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
