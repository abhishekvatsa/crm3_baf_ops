import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/furnace_stuckup_record.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

final furnaceStuckupCasesProvider = StreamProvider<List<FurnaceStuckupRecord>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('furnace_stuckup_cases')
      .snapshots()
      .map((snapshot) {
        final records =
            decodeSnapshotDocuments(snapshot, FurnaceStuckupRecord.fromMap, source: 'FurnaceStuckupRecord')
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
                decodeSnapshotDocuments(snapshot, AssetConditionDeclarationRecord.fromMap, source: 'AssetConditionDeclarationRecord')
                    .toList()
                  ..sort(
                    (left, right) =>
                        right.latestEvidenceAt.compareTo(left.latestEvidenceAt),
                  );
            return List<AssetConditionDeclarationRecord>.unmodifiable(records);
          });
    });
