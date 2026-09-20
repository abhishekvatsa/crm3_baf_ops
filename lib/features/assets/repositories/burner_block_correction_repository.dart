import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../data/burner_block_installation_correction.dart';
import '../data/burner_block_lifecycle_event.dart';

class BurnerBlockCorrectionReview {
  const BurnerBlockCorrectionReview({
    required this.original,
    required this.current,
    required this.corrections,
    required this.effectiveCorrection,
  });
  final BurnerBlockLifecycleEvent original, current;
  final List<BurnerBlockInstallationCorrection> corrections;
  final BurnerBlockInstallationCorrection? effectiveCorrection;
  DateTime get effectiveAt =>
      effectiveCorrection?.effectiveAt ?? original.actionPerformedAt;
}

class BurnerBlockCorrectionRepository {
  const BurnerBlockCorrectionRepository({required this.firestore});
  final FirebaseFirestore firestore;

  Future<BurnerBlockCorrectionReview> review(String eventId) async {
    final originalSnapshot = await firestore
        .collection('burner_block_lifecycle_events')
        .doc(eventId)
        .get(const GetOptions(source: Source.server));
    if (!originalSnapshot.exists ||
        originalSnapshot.data() == null ||
        originalSnapshot.metadata.isFromCache ||
        originalSnapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The original installation could not be verified from the server.',
      );
    }
    final original = BurnerBlockLifecycleEvent.fromMap(
      originalSnapshot.data()!,
      eventId,
    );
    final snapshots = await firestore
        .collection('burner_block_lifecycle_corrections')
        .where('correctsEventId', isEqualTo: eventId)
        .get(const GetOptions(source: Source.server));
    if (snapshots.metadata.isFromCache || snapshots.metadata.hasPendingWrites) {
      throw StateError(
        'The complete correction history could not be verified.',
      );
    }
    final corrections = snapshots.docs
        .map(
          (doc) =>
              BurnerBlockInstallationCorrection.fromMap(doc.data(), doc.id),
        )
        .toList();
    if (corrections.any(
      (row) =>
          row.assetInstanceId != original.assetInstanceId ||
          row.burnerPosition != original.burnerPosition ||
          !row.originalAt.isAtSameMomentAs(original.actionPerformedAt),
    )) {
      throw StateError(
        'Correction history disagrees with the original physical subject.',
      );
    }
    final effective = effectiveBurnerBlockCorrection(corrections, eventId);
    final current = await _current(
      original.assetInstanceId,
      original.burnerPosition,
    );
    return BurnerBlockCorrectionReview(
      original: original,
      current: current,
      corrections: List.unmodifiable(corrections),
      effectiveCorrection: effective,
    );
  }

  Future<BurnerBlockLifecycleEvent> _current(
    String assetId,
    int position,
  ) async {
    final snapshot = await firestore
        .collection('burner_block_lifecycle_current')
        .where('assetInstanceId', isEqualTo: assetId)
        .get(const GetOptions(source: Source.server));
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Current installations could not be confirmed.');
    }
    final rows = snapshot.docs
        .map(
          (doc) => BurnerBlockLifecycleEvent.fromCurrentMap(doc.data(), doc.id),
        )
        .where((row) => row.burnerPosition == position)
        .toList();
    if (rows.length != 1 || rows.single.assetInstanceId != assetId) {
      throw StateError(
        'The position has missing or conflicting current installation evidence.',
      );
    }
    return rows.single;
  }

  Future<void> confirmReadback(
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson,
  ) async {
    final result = receipt.result;
    final id = result['correctionId'];
    if (id is! String || id.isEmpty) {
      throw StateError('The accepted correction has no identity.');
    }
    final snapshot = await firestore
        .collection('burner_block_lifecycle_corrections')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists ||
        snapshot.data() == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The correction was accepted; its server readback remains pending.',
      );
    }
    final correction = verifyCorrectionReadback(
      snapshot.data()!,
      id,
      receipt,
      originalEnvelopeJson,
    );
    // A newer legitimate installation may now be current. Validate the current
    // subject, never require it to equal an earlier correction's after-image.
    await _current(correction.assetInstanceId, correction.burnerPosition);
  }

  /// Shared by the actual server read and contract tests with persisted timestamps.
  static BurnerBlockInstallationCorrection verifyCorrectionReadback(
    Map<String, dynamic> data,
    String id,
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson,
  ) {
    final envelope = durableSubmissionJsonObject(originalEnvelopeJson);
    final command = envelope['command'] as Map<String, dynamic>;
    final payload = command['payload'] as Map<String, dynamic>;
    final result = receipt.result;
    final correction = BurnerBlockInstallationCorrection.fromMap(data, id);
    if (correction.eventId != result['correctsEventId'] ||
        correction.expectedCurrentEventId != result['expectedCurrentEventId'] ||
        correction.expectedCurrentEventId !=
            payload['expectedCurrentEventId'] ||
        correction.reason != (payload['reason'] as String).trim() ||
        correction.reviewerUid != envelope['originActorUid'] ||
        !correction.correctedAt.isAtSameMomentAs(receipt.appliedAt) ||
        !correction.originalAt.isAtSameMomentAs(
          readRequiredPersistedDateTime(
            result['recordedActionPerformedAt'],
            field: 'recordedActionPerformedAt',
            source: 'correction receipt',
          ),
        ) ||
        correction.assetInstanceId != result['assetInstanceId'] ||
        correction.burnerPosition != result['burnerPosition'] ||
        correction.supersedesId != result['supersedesCorrectionId'] ||
        correction.effectiveAt !=
            readRequiredPersistedDateTime(
              result['correctedActionPerformedAt'],
              field: 'correctedActionPerformedAt',
              source: 'correction receipt',
            ).toUtc()) {
      throw StateError(
        'The correction is accepted but its retained server evidence disagrees.',
      );
    }
    return correction;
  }
}
