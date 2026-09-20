part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// DIRECTIVES (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullDirectives on GlobalPullService {
  Future<void> _pullDirectives(DateTime? lastSync, DateTime through) async {
    DocumentSnapshot? startAfter;
    final uid = _authentication.currentUser!.uid;
    try {
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

        if (result.rejectedIds.isNotEmpty) {
          _hadRecordProcessingError = true;
          lastSkipped += result.rejectedIds.length;
          debugPrint(
            'Directive pull retained failed identities: ${result.rejectedIds.join(', ')}. The domain cursor will not advance.',
          );
        }
        if (result.rawCount == 0) break;

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
            final result = await _directiveRepo.applyDirectiveFromRemote(
              remote,
            );
            _recordRemoteApplyResult('operational directive', remote, result);
          } catch (e) {
            lastSkipped++;
            _hadRecordProcessingError = true;
            debugPrint('⚠️ Directive pull error: $e');
          }
        }

        if (result.rawCount < GlobalPullService._pageSize) break;
        if (startAfter == null) break;
      }
      await DirectiveReadHealth.record(
        uid,
        _hadRecordProcessingError || _hadCleanLocalReconciliation,
      );
    } catch (_) {
      await DirectiveReadHealth.record(uid, true);
      rethrow;
    }
  }
}
