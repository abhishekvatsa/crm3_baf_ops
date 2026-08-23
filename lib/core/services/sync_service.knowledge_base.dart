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
        _permanentRejectionIdsUnderRecheck.add(rejection.id);
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
      if (pushed > 0) {
        await _resolveRecheckedPermanentRejections(
          entityType: 'baf_knowledge_row',
          entityIds: const <String>{'knowledge_base_batch'},
          evidence:
              'Every pending knowledge row returned a server receipt and was reconciled locally.',
        );
      }
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
