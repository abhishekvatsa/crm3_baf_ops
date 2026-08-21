import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/maintenance_intelligence.dart';

class MaintenanceIntelligenceRepository {
  MaintenanceIntelligenceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<MaintenanceClassDefinition>> watchClasses() => _firestore
      .collection('maintenance_class_definitions')
      .snapshots()
      .map((snapshot) {
        final rows = snapshot.docs
          .map((doc) => MaintenanceClassDefinition.fromMap(doc.data(), doc.id))
          .toList(growable: false)..sort((a, b) {
          final status = a.status.index.compareTo(b.status.index);
          return status != 0 ? status : a.title.compareTo(b.title);
        });
        return List.unmodifiable(rows);
      });

  Stream<List<MaintenanceDueState>> watchDueStates() => _firestore
      .collection('maintenance_due_states')
      .snapshots()
      .map((snapshot) {
        final rows = snapshot.docs
          .map((doc) => MaintenanceDueState.fromMap(doc.data(), doc.id))
          .toList(growable: false)..sort((a, b) {
          if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
          final aDue = a.nextDueAt ?? DateTime(9999);
          final bDue = b.nextDueAt ?? DateTime(9999);
          return aDue.compareTo(bDue);
        });
        return List.unmodifiable(rows);
      });

  Stream<List<MaintenanceCompletionEvent>> watchCompletionEvents() => _firestore
      .collection('maintenance_completion_events')
      .snapshots()
      .map((snapshot) {
        final rows = snapshot.docs
          .map((doc) => MaintenanceCompletionEvent.fromMap(doc.data(), doc.id))
          .toList(
            growable: false,
          )..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        return List.unmodifiable(rows);
      });

  Stream<List<MaintenancePlan>> watchPlans() =>
      _firestore.collection('maintenance_plans').snapshots().map((snapshot) {
        final rows = snapshot.docs
            .map((doc) => MaintenancePlan.fromMap(doc.data(), doc.id))
            .toList(growable: false)
          ..sort((a, b) => a.targetWindowStart.compareTo(b.targetWindowStart));
        return List.unmodifiable(rows);
      });
}
