import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/user_model.dart';
import '../data/baf_knowledge_model.dart';
import '../domain/knowledge_correction_promoter.dart';

abstract interface class KnowledgeCorrectionSourceRepository {
  Future<List<HarvestableTemplateSnapshot>> loadPublishedSnapshots();
}

class FirestoreKnowledgeCorrectionSourceRepository
    implements KnowledgeCorrectionSourceRepository {
  FirestoreKnowledgeCorrectionSourceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<HarvestableTemplateSnapshot>> loadPublishedSnapshots() async {
    final snap =
        await _firestore
            .collection('template_versions')
            .where('status', isEqualTo: 'published')
            .orderBy('publishedAt', descending: true)
            .limit(50)
            .get();
    final snapshots = <HarvestableTemplateSnapshot>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final json = (data['jobTemplateSnapshotJson'] ?? '').toString();
      if (json.isEmpty) continue;
      final publishedAt = data['publishedAt'];
      final harvestedAt =
          publishedAt is Timestamp
              ? publishedAt.toDate()
              : (publishedAt is DateTime ? publishedAt : DateTime.now());
      snapshots.add(
        HarvestableTemplateSnapshot(
          versionFirestoreId: doc.id,
          packageCode: (data['packageCode'] ?? '').toString(),
          versionNumber:
              data['versionNumber'] is num
                  ? (data['versionNumber'] as num).toInt()
                  : 0,
          jobTemplateSnapshotJson: json,
          harvestedAt: harvestedAt,
        ),
      );
    }
    return snapshots;
  }
}

class KnowledgeCorrectionSourceService {
  const KnowledgeCorrectionSourceService(this._repository);

  final KnowledgeCorrectionSourceRepository _repository;

  Future<List<PromotableTagCorrection>> loadPromotableCorrections({
    required AppUser? actor,
    required Map<String, BafKnowledgeRow> existingRowsByCode,
  }) async {
    if (actor == null || !actor.canManageTemplateGovernance) {
      throw StateError(
        'Admin/SI access is required before reading template corrections.',
      );
    }
    final snapshots = await _repository.loadPublishedSnapshots();
    return KnowledgeCorrectionPromoter.harvestMany(
      snapshots: snapshots,
      existingRowsByCode: existingRowsByCode,
    );
  }
}
