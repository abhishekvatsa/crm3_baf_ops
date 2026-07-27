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

      final inserts = <OperationalDirective>[];
      final updates = <OperationalDirective>[];
      final tombstones = <OperationalDirective>[];

      for (final remote in directives) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _directiveRepo.getByFirestoreId(
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
              _logPullConflict('directive', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Directive pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _directiveRepo.applyTombstoneFromDirectiveRemote(
          remote,
        );
        _recordTombstoneApplyResult('operational directive', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _directiveRepo.insertFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _directiveRepo.updateFromRemote(remote);
        lastUpdated++;
      }

      if (directives.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
