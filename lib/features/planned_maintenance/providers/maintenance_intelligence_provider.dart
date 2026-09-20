import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/maintenance_intelligence.dart';
import '../repositories/maintenance_intelligence_repository.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

final maintenanceIntelligenceRepositoryProvider =
    Provider<MaintenanceIntelligenceRepository>((ref) {
      return MaintenanceIntelligenceRepository();
    });

final maintenanceClassDefinitionsProvider =
    StreamProvider<DecodedSnapshotBatch<MaintenanceClassDefinition>>((ref) {
      return ref
          .watch(maintenanceIntelligenceRepositoryProvider)
          .watchClasses();
    });

final maintenanceDueStatesProvider =
    StreamProvider<DecodedSnapshotBatch<MaintenanceDueState>>((ref) {
      return ref
          .watch(maintenanceIntelligenceRepositoryProvider)
          .watchDueStates();
    });

/// Keeps visible due/overdue labels current even when Firestore has not
/// emitted a new snapshot at the deadline boundary.
final maintenanceCadenceClockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  ),
);

final maintenanceCompletionEventsProvider =
    StreamProvider<DecodedSnapshotBatch<MaintenanceCompletionEvent>>((ref) {
      return ref
          .watch(maintenanceIntelligenceRepositoryProvider)
          .watchCompletionEvents();
    });

final maintenancePlansProvider =
    StreamProvider<DecodedSnapshotBatch<MaintenancePlan>>((ref) {
  return ref.watch(maintenanceIntelligenceRepositoryProvider).watchPlans();
});
