import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/maintenance_intelligence.dart';
import '../repositories/maintenance_intelligence_repository.dart';

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

final maintenanceDueStatesProvider = StreamProvider<List<MaintenanceDueState>>((
  ref,
) {
  return ref.watch(maintenanceIntelligenceRepositoryProvider).watchDueStates();
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
