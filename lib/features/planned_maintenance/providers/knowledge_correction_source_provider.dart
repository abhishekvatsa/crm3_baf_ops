import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../data/baf_knowledge_model.dart';
import '../domain/knowledge_correction_promoter.dart';
import '../repositories/knowledge_correction_source_repository.dart';
import 'knowledge_governance_provider.dart';

final knowledgeCorrectionSourceRepositoryProvider =
    Provider<KnowledgeCorrectionSourceRepository>(
      (ref) => FirestoreKnowledgeCorrectionSourceRepository(),
    );

final knowledgeCorrectionSourceServiceProvider =
    Provider<KnowledgeCorrectionSourceService>(
      (ref) => KnowledgeCorrectionSourceService(
        ref.watch(knowledgeCorrectionSourceRepositoryProvider),
      ),
    );

final knowledgePromotableCorrectionsProvider = FutureProvider.autoDispose
    .family<List<PromotableTagCorrection>, AppUser>((ref, actor) async {
      final view = ref.watch(knowledgeRowsViewProvider).valueOrNull;
      final byCode = <String, BafKnowledgeRow>{
        for (final row in view?.rows ?? const <BafKnowledgeRow>[])
          row.rowCode: row,
      };
      return ref
          .watch(knowledgeCorrectionSourceServiceProvider)
          .loadPromotableCorrections(actor: actor, existingRowsByCode: byCode);
    });
