import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/maintenance_intelligence.dart';
import '../repositories/maintenance_intelligence_repository.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

final maintenanceIntelligenceRepositoryProvider =
    Provider<MaintenanceIntelligenceRepository>((ref) {
      return MaintenanceIntelligenceRepository();
    });

final maintenanceClassDefinitionsProvider =
    StreamProvider<List<MaintenanceClassDefinition>>((ref) {
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

final maintenanceCompletionEventsProvider =
    StreamProvider<List<MaintenanceCompletionEvent>>((ref) {
      return ref
          .watch(maintenanceIntelligenceRepositoryProvider)
          .watchCompletionEvents();
    });

final maintenancePlansProvider = StreamProvider<List<MaintenancePlan>>((ref) {
  return ref.watch(maintenanceIntelligenceRepositoryProvider).watchPlans();
});
