import 'package:isar/isar.dart';

import '../../../core/services/isar_installed_store_provenance.dart';
import '../../../core/services/isar_schema_guard.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../audit/models/audit_event_model.dart';
import '../../charges/data/charge_model.dart';
import '../../directives/data/operational_directive_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/baf_knowledge_model.dart';
import '../../planned_maintenance/data/job_diary_model.dart';
import '../../planned_maintenance/data/job_module_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/data/template_governance_model.dart';

class LocalDiagnosticsCollectionSnapshot {
  const LocalDiagnosticsCollectionSnapshot({
    required this.label,
    required this.totalCount,
    required this.unsyncedCount,
    this.note,
  });

  final String label;
  final int totalCount;
  final int unsyncedCount;
  final String? note;
}

class LocalDiagnosticsGovernanceSnapshot {
  const LocalDiagnosticsGovernanceSnapshot({
    required this.activePackages,
    required this.retiredPackages,
    required this.archivedPackages,
    required this.publishedVersions,
    required this.draftVersions,
    required this.retiredVersions,
    required this.archivedVersions,
    required this.publishAuditRows,
  });

  final int activePackages;
  final int retiredPackages;
  final int archivedPackages;
  final int publishedVersions;
  final int draftVersions;
  final int retiredVersions;
  final int archivedVersions;
  final int publishAuditRows;
}

class LocalDiagnosticsPersistenceSnapshot {
  const LocalDiagnosticsPersistenceSnapshot({
    required this.rows,
    required this.unresolvedRejections,
    required this.likelyPermanentRejections,
    required this.totalRejections,
    required this.knowledgeMetaRows,
    required this.governance,
    required this.provenanceInventory,
  });

  final List<LocalDiagnosticsCollectionSnapshot> rows;
  final int unresolvedRejections;
  final int likelyPermanentRejections;
  final int totalRejections;
  final int knowledgeMetaRows;
  final LocalDiagnosticsGovernanceSnapshot governance;
  final IsarInstalledStoreProvenanceInventory provenanceInventory;
}

/// Privileged, read-only adapter for the privacy-safe local diagnostics screen.
class LocalDiagnosticsReadAdapter {
  LocalDiagnosticsReadAdapter({Isar? Function()? databaseLookup})
    : _databaseLookup = databaseLookup ?? Isar.getInstance;

  final Isar? Function() _databaseLookup;

  Future<LocalDiagnosticsPersistenceSnapshot> read() async {
    final database = _databaseLookup();
    if (database == null) {
      throw StateError('Local database is not available.');
    }
    final provenance =
        readStartupPreOpenIsarProvenanceInventory() ??
        await readPrivacySafeIsarProvenanceInventory();

    final rows = <LocalDiagnosticsCollectionSnapshot>[
      await _row(
        'Maintenance tickets',
        database.maintenanceRecords.where().count,
        () =>
            database.maintenanceRecords.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Legacy job templates',
        database.jobTemplates.where().count,
        () => database.jobTemplates.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Job executions',
        database.jobExecutions.where().count,
        () => database.jobExecutions.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Job modules',
        database.jobModuleInstances.where().count,
        () =>
            database.jobModuleInstances.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Job diary entries',
        database.jobDiaryEntrys.where().count,
        () => database.jobDiaryEntrys.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Operational directives',
        database.operationalDirectives.where().count,
        () =>
            database.operationalDirectives
                .filter()
                .isSyncedEqualTo(false)
                .count(),
      ),
      await _row(
        'Abnormality types',
        database.abnormalityTypes.where().count,
        () => database.abnormalityTypes.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Charge abnormalities',
        database.chargeAbnormalitys.where().count,
        () =>
            database.chargeAbnormalitys.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Template packages',
        database.templatePackages.where().count,
        () => database.templatePackages.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Template versions',
        database.templateVersions.where().count,
        () => database.templateVersions.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Template publish audits',
        database.templatePublishAudits.where().count,
        () =>
            database.templatePublishAudits
                .filter()
                .isSyncedEqualTo(false)
                .count(),
      ),
      await _row(
        'BAF knowledge rows',
        database.bafKnowledgeRows.where().count,
        () => database.bafKnowledgeRows.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Audit events',
        database.auditEvents.where().count,
        () => database.auditEvents.filter().isSyncedEqualTo(false).count(),
      ),
      await _row(
        'Base Charge rows (reserved future integration)',
        database.charges.where().count,
        () => database.charges.filter().isSyncedEqualTo(false).count(),
        note:
            'Reserved for future IoT / Level-2 integration; not an app-owned operational sync entity today.',
      ),
    ];

    return LocalDiagnosticsPersistenceSnapshot(
      rows: rows,
      unresolvedRejections:
          await database.syncRejections
              .filter()
              .isResolvedEqualTo(false)
              .count(),
      likelyPermanentRejections:
          await database.syncRejections
              .filter()
              .isResolvedEqualTo(false)
              .isLikelyPermanentEqualTo(true)
              .count(),
      totalRejections: await database.syncRejections.where().count(),
      knowledgeMetaRows:
          await database.bafKnowledgeMatrixMetaStores.where().count(),
      governance: await _readGovernance(database),
      provenanceInventory: provenance,
    );
  }

  Future<LocalDiagnosticsGovernanceSnapshot> _readGovernance(
    Isar database,
  ) async {
    return LocalDiagnosticsGovernanceSnapshot(
      activePackages:
          await database.templatePackages
              .filter()
              .isDeletedEqualTo(false)
              .lifecycleStatusEqualTo(TemplatePackageLifecycleStatus.active)
              .count(),
      retiredPackages:
          await database.templatePackages
              .filter()
              .isDeletedEqualTo(false)
              .lifecycleStatusEqualTo(TemplatePackageLifecycleStatus.retired)
              .count(),
      archivedPackages:
          await database.templatePackages
              .filter()
              .isDeletedEqualTo(false)
              .lifecycleStatusEqualTo(TemplatePackageLifecycleStatus.archived)
              .count(),
      publishedVersions:
          await database.templateVersions
              .filter()
              .isDeletedEqualTo(false)
              .statusEqualTo(TemplateVersionStatus.published)
              .count(),
      draftVersions:
          await database.templateVersions
              .filter()
              .isDeletedEqualTo(false)
              .statusEqualTo(TemplateVersionStatus.draft)
              .count(),
      retiredVersions:
          await database.templateVersions
              .filter()
              .isDeletedEqualTo(false)
              .statusEqualTo(TemplateVersionStatus.retired)
              .count(),
      archivedVersions:
          await database.templateVersions
              .filter()
              .isDeletedEqualTo(false)
              .statusEqualTo(TemplateVersionStatus.archived)
              .count(),
      publishAuditRows: await database.templatePublishAudits.where().count(),
    );
  }

  static Future<LocalDiagnosticsCollectionSnapshot> _row(
    String label,
    Future<int> Function() total,
    Future<int> Function() unsynced, {
    String? note,
  }) async {
    return LocalDiagnosticsCollectionSnapshot(
      label: label,
      totalCount: await total(),
      unsyncedCount: await unsynced(),
      note: note,
    );
  }
}
