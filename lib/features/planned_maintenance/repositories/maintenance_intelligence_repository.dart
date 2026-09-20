import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/maintenance_intelligence.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

class MaintenanceIntelligenceRepository {
  MaintenanceIntelligenceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<MaintenancePlan> readPlanFromServer(String planId) async {
    final snapshot = await _firestore
        .collection('maintenance_plans')
        .doc(planId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists ||
        snapshot.data() == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The current maintenance plan could not be verified with the server.',
      );
    }
    return MaintenancePlan.fromMap(snapshot.data()!, snapshot.id);
  }

  Stream<DecodedSnapshotBatch<MaintenanceClassDefinition>> watchClasses() =>
      _firestore
          .collection('maintenance_class_definitions')
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
            final batch = decodeSnapshotBatch(
              snapshot,
              MaintenanceClassDefinition.fromMap,
              source: 'MaintenanceClassDefinition',
            );
            final rows = batch.records.toList(growable: false)
              ..sort((a, b) {
                final status = a.status.index.compareTo(b.status.index);
                return status != 0 ? status : a.title.compareTo(b.title);
              });
            return DecodedSnapshotBatch<MaintenanceClassDefinition>(
              records: List.unmodifiable(rows),
              rejectedDocumentIds: batch.rejectedDocumentIds,
              isFromCache: batch.isFromCache,
              hasPendingWrites: batch.hasPendingWrites,
            );
          });

  /// Due state is read as a batch, not a plain list. The screen and the
  /// operations report turn this into headline counts, and "nothing is
  /// overdue" is a statement about the plant rather than about what happened
  /// to decode. A row that could not be read has to travel with the count.
  Stream<DecodedSnapshotBatch<MaintenanceDueState>> watchDueStates() =>
      _firestore
          .collection('maintenance_due_states')
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
            final batch = decodeSnapshotBatch(
              snapshot,
              MaintenanceDueState.fromMap,
              source: 'MaintenanceDueState',
            );
            final rows = batch.records.toList(growable: false)
              ..sort((a, b) {
                if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
                final aDue = a.nextDueAt ?? DateTime(9999);
                final bDue = b.nextDueAt ?? DateTime(9999);
                return aDue.compareTo(bDue);
              });
            return DecodedSnapshotBatch<MaintenanceDueState>(
              records: List.unmodifiable(rows),
              rejectedDocumentIds: batch.rejectedDocumentIds,
              isFromCache: batch.isFromCache,
              hasPendingWrites: batch.hasPendingWrites,
            );
          });

  Stream<DecodedSnapshotBatch<MaintenanceCompletionEvent>>
  watchCompletionEvents() => _firestore
      .collection('maintenance_completion_events')
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final batch = decodeSnapshotBatch(
          snapshot,
          MaintenanceCompletionEvent.fromMap,
          source: 'MaintenanceCompletionEvent',
        );
        final rows = batch.records.toList(growable: false)
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        return DecodedSnapshotBatch<MaintenanceCompletionEvent>(
          records: List.unmodifiable(rows),
          rejectedDocumentIds: batch.rejectedDocumentIds,
          isFromCache: batch.isFromCache,
          hasPendingWrites: batch.hasPendingWrites,
        );
      });

  Stream<DecodedSnapshotBatch<MaintenancePlan>> watchPlans() => _firestore
      .collection('maintenance_plans')
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final batch = decodeSnapshotBatch(
          snapshot,
          MaintenancePlan.fromMap,
          source: 'MaintenancePlan',
        );
        final rows = batch.records.toList(growable: false)
          ..sort((a, b) => a.targetWindowStart.compareTo(b.targetWindowStart));
        return DecodedSnapshotBatch<MaintenancePlan>(
          records: List.unmodifiable(rows),
          rejectedDocumentIds: batch.rejectedDocumentIds,
          isFromCache: batch.isFromCache,
          hasPendingWrites: batch.hasPendingWrites,
        );
      });
}
