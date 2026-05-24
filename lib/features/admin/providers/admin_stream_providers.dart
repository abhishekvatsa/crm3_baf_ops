import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../directives/data/operational_directive_model.dart';
import '../../directives/providers/operational_directive_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';

final adminTicketsStreamProvider = StreamProvider<List<MaintenanceRecord>>((
  ref,
) {
  return ref.watch(maintenanceRepositoryProvider).watchAllTickets();
});

final adminDirectivesStreamProvider =
    StreamProvider<List<OperationalDirective>>((ref) {
      return ref.watch(directiveRepositoryProvider).watchAllDirectives();
    });

final adminTemplatesStreamProvider = StreamProvider<List<JobTemplate>>((ref) {
  return ref.watch(plannedRepositoryProvider).watchAllTemplates();
});

final adminExecutionsStreamProvider = StreamProvider<List<JobExecution>>((ref) {
  return ref.watch(plannedRepositoryProvider).watchAllExecutions();
});
