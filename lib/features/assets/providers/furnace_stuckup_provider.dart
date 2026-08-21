import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/furnace_stuckup_record.dart';

final furnaceStuckupCasesProvider = StreamProvider<List<FurnaceStuckupRecord>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('furnace_stuckup_cases')
      .snapshots()
      .map((snapshot) {
        final records =
            snapshot.docs
                .map((doc) => FurnaceStuckupRecord.fromMap(doc.data(), doc.id))
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
          .snapshots()
          .map((snapshot) {
            final records =
                snapshot.docs
                    .map(
                      (doc) => AssetConditionDeclarationRecord.fromMap(
                        doc.data(),
                        doc.id,
                      ),
                    )
                    .toList()
                  ..sort(
                    (left, right) =>
                        right.latestEvidenceAt.compareTo(left.latestEvidenceAt),
                  );
            return List<AssetConditionDeclarationRecord>.unmodifiable(records);
          });
    });
