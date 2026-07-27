part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// KNOWLEDGE BASE
// ─────────────────────────────────────────────────────────────

extension _GlobalPullKnowledgeBase on GlobalPullService {
  Future<void> _pullKnowledgeBase(DateTime? lastSync, DateTime through) async {
    try {
      final result = await _knowledgeRepo.pullCloudToLocal(lastSync, through);
      lastInserted += result.inserted;
      lastUpdated += result.updated;
      lastSkipped += result.skipped;
    } catch (e, stackTrace) {
      _hadRecordProcessingError = true;
      debugPrint('❌ Knowledge Base pull failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
