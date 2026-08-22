part of 'sync_service.dart';

extension _SyncServiceKnowledgeBase on SyncService {
  Future<bool> _isKnowledgeBaseBatchHeldByPermanentRejection() async {
    if (kIsWeb) return false;
    final localIsar = Isar.getInstance();
    if (localIsar == null) return false;

    try {
      final rejection =
          await localIsar.syncRejections
              .filter()
              .entityTypeEqualTo('baf_knowledge_row')
              .and()
              .entityIdEqualTo('knowledge_base_batch')
              .and()
              .isResolvedEqualTo(false)
              .and()
              .isLikelyPermanentEqualTo(true)
              .findFirst();

      if (rejection == null) return false;

      if (_recheckPermanentRejections) {
        await localIsar.writeTxn(() async {
          final current = await localIsar.syncRejections.get(rejection.id);
          if (current == null || current.isResolved) return;
          current.markResolved(
            notes:
                'Manual server recheck released the knowledge-row retry hold. No source row was marked synchronized, changed, or deleted by this action.',
          );
          await localIsar.syncRejections.put(current);
        });
        return false;
      }

      _recordAutomaticRetryHeld(
        entityType: 'baf_knowledge_row',
        entityId: 'knowledge_base_batch',
        rejection: rejection,
      );
      return true;
    } catch (e, st) {
      debugPrint(
        '⚠️ Could not inspect knowledge-base sync rejection hold state: $e',
      );
      debugPrint('$st');
      return false;
    }
  }

  Future<void> _syncKnowledgeBase() async {
    if (await _isKnowledgeBaseBatchHeldByPermanentRejection()) {
      return;
    }

    try {
      final pushed = await _knowledgeRepo.syncUnsyncedToCloud();
      lastSuccessCount += pushed;
    } catch (e, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'baf_knowledge_row',
        entityId: 'knowledge_base_batch',
        error: e,
      );
      debugPrint('❌ Knowledge Base sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
