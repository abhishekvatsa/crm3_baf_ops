// FILE: lib/core/services/planned_job_local_link_repair.dart

import 'package:isar/isar.dart';

import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';

/// Result of the idempotent repair that removes transported device-local
/// parent ids from remote-backed planned-maintenance child records.
class PlannedJobLocalLinkRepairReport {
  final int repairedModules;
  final int repairedDiaryExecutionLinks;
  final int repairedDiaryModuleLinks;

  const PlannedJobLocalLinkRepairReport({
    required this.repairedModules,
    required this.repairedDiaryExecutionLinks,
    required this.repairedDiaryModuleLinks,
  });

  int get totalRepairs =>
      repairedModules + repairedDiaryExecutionLinks + repairedDiaryModuleLinks;

  bool get changed => totalRepairs > 0;
}

/// Local-only, idempotent data repair.
///
/// A non-empty Firestore parent is authoritative. The associated Isar integer
/// is device-local and must not remain as a second cross-device relationship.
/// This repair changes only those local-link fields; it does not delete rows,
/// alter evidence/lifecycle fields, bump versions, mark rows dirty, or write
/// Firestore.
Future<PlannedJobLocalLinkRepairReport> repairPlannedJobLocalLinks(
  Isar isar,
) async {
  var repairedModules = 0;
  var repairedDiaryExecutionLinks = 0;
  var repairedDiaryModuleLinks = 0;

  await isar.writeTxn(() async {
    final modules =
        await isar.jobModuleInstances
            .filter()
            .jobExecutionFirestoreIdIsNotNull()
            .and()
            .jobExecutionLocalIdIsNotNull()
            .findAll();
    final changedModules = <JobModuleInstance>[];

    for (final module in modules) {
      if (_hasText(module.jobExecutionFirestoreId)) {
        module.jobExecutionLocalId = null;
        changedModules.add(module);
        repairedModules += 1;
      }
    }

    if (changedModules.isNotEmpty) {
      await isar.jobModuleInstances.putAll(changedModules);
    }

    final diaryEntries =
        await isar.jobDiaryEntrys
            .filter()
            .jobExecutionLocalIdIsNotNull()
            .or()
            .moduleInstanceLocalIdIsNotNull()
            .findAll();
    final changedEntries = <JobDiaryEntry>[];

    for (final entry in diaryEntries) {
      var changed = false;

      if (_hasText(entry.jobExecutionFirestoreId) &&
          entry.jobExecutionLocalId != null) {
        entry.jobExecutionLocalId = null;
        repairedDiaryExecutionLinks += 1;
        changed = true;
      }

      if (_hasText(entry.moduleInstanceFirestoreId) &&
          entry.moduleInstanceLocalId != null) {
        entry.moduleInstanceLocalId = null;
        repairedDiaryModuleLinks += 1;
        changed = true;
      }

      if (changed) changedEntries.add(entry);
    }

    if (changedEntries.isNotEmpty) {
      await isar.jobDiaryEntrys.putAll(changedEntries);
    }
  });

  return PlannedJobLocalLinkRepairReport(
    repairedModules: repairedModules,
    repairedDiaryExecutionLinks: repairedDiaryExecutionLinks,
    repairedDiaryModuleLinks: repairedDiaryModuleLinks,
  );
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
