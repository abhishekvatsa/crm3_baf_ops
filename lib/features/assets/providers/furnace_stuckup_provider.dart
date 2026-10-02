import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/furnace_stuckup_record.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../auth/providers/auth_provider.dart';


final furnaceStuckupCasesProvider = StreamProvider<List<FurnaceStuckupRecord>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('furnace_stuckup_cases')
      .snapshots()
      .map((snapshot) {
        final records =
            snapshot.docs.map((doc) => FurnaceStuckupRecord.fromMap(doc.data(), doc.id))
                .toList()
              ..sort(
                (left, right) => right.reportedAt.compareTo(left.reportedAt),
              );
        return List<FurnaceStuckupRecord>.unmodifiable(records);
      });
});

final assetConditionDeclarationsProvider =
    StreamProvider<List<AssetConditionDeclarationRecord>>((ref) {
      return FirebaseFirestore.instance
          .collection('asset_condition_declarations')
          .where('conditionType', isEqualTo: 'innerCoverBulged')
          .snapshots()
          .map((snapshot) {
            final records =
                snapshot.docs.map((doc) => AssetConditionDeclarationRecord.fromMap(doc.data(), doc.id))
                    .toList()
                  ..sort(
                    (left, right) =>
                        right.latestEvidenceAt.compareTo(left.latestEvidenceAt),
                  );
            return List<AssetConditionDeclarationRecord>.unmodifiable(records);
          });
    });

// Qualified variants for stock summaries. Keep the existing strict list readers
// above unchanged: an unreadable condition must still fail those consumers.
final furnaceStuckupCaseBatchProvider =
    StreamProvider.autoDispose<DecodedSnapshotBatch<FurnaceStuckupRecord>>((
      ref,
    ) {
      if (ref.watch(currentAppUserProvider).asData?.value?.isApproved != true) {
        throw StateError('Approved plant-condition access is required.');
      }
      return FirebaseFirestore.instance
          .collection('furnace_stuckup_cases')
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => decodeSnapshotBatch(
              snapshot,
              FurnaceStuckupRecord.fromMap,
              source: 'FurnaceStuckupRecord',
            ),
          );
    });

final innerCoverBulgeDeclarationBatchProvider =
    StreamProvider.autoDispose<
      DecodedSnapshotBatch<AssetConditionDeclarationRecord>
    >((ref) {
      if (ref.watch(currentAppUserProvider).asData?.value?.isApproved != true) {
        throw StateError('Approved plant-condition access is required.');
      }
      return FirebaseFirestore.instance
          .collection('asset_condition_declarations')
          .where('conditionType', isEqualTo: 'innerCoverBulged')
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => decodeSnapshotBatch(
              snapshot,
              AssetConditionDeclarationRecord.fromMap,
              source: 'AssetConditionDeclarationRecord',
            ),
          );
    });
