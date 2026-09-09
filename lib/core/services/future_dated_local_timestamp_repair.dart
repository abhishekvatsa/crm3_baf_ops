import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../features/audit/models/audit_event_model.dart';
import '../../features/audit/repositories/audit_repository.dart';

import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import 'server_anchored_clock.dart';

class FutureDatedLocalTimestampRepairReport {
  final Map<String, int> repairedByCollection;

  /// Collections the repair could not reach, by failure reason. A partial
  /// repair still unblocks the domains it did reach, so this is reported
  /// rather than raised.
  final Map<String, String> skippedByCollection;
  final Duration appliedOffset;

  const FutureDatedLocalTimestampRepairReport({
    required this.repairedByCollection,
    required this.appliedOffset,
    this.skippedByCollection = const <String, String>{},
  });

  int get repairedRecords =>
      repairedByCollection.values.fold(0, (sum, count) => sum + count);

  bool get changed => repairedRecords > 0;

  @override
  String toString() {
    final skippedNote = skippedByCollection.isEmpty
        ? ''
        : ' skipped=${skippedByCollection.keys.toList()}';
    return 'repaired=$repairedRecords '
        'offset=${appliedOffset.inSeconds}s '
        '$repairedByCollection$skippedNote';
  }
}

/// Re-anchors clean local rows whose `updatedAt` was stamped by a device clock
/// running ahead of the backend.
///
/// A clean row is the local mirror of a server record. When its `updatedAt`
/// sits in the server's future, every higher server version arrives carrying an
/// earlier instant, the remote-freshness guard preserves the local row, and the
/// domain pull cursor stops advancing. That state never clears on its own,
/// because nothing rewrites the row: the device stays stalled for that domain
/// indefinitely.
///
/// Two rules keep the repair conservative:
///
/// * **Only clean rows.** A dirty row holds unpushed local evidence, and its
///   timestamp is part of that evidence. Those are left untouched and continue
///   through the ordinary push and conflict paths.
/// * **Only provably impossible instants.** A row is repaired only when its
///   `updatedAt` is later than the anchored server time by more than
///   [_serverFutureTolerance]. A genuine server-authored instant can never sit
///   meaningfully in the server's own future, so this cannot catch a correctly
///   mirrored row.
///
/// The corrected value reconstructs the server-timeline instant the write would
/// have carried, by applying the same offset the clock now uses. Clamping to
/// "now" would be insufficient: a pending server version may itself predate
/// now, and would still be rejected.
///
/// No version, sync state, business field, or remote document is changed.
Future<FutureDatedLocalTimestampRepairReport?> repairFutureDatedLocalTimestamps(
  Isar isar, {
  DateTime Function()? anchoredNow,
  Duration? offset,
}) async {
  final appliedOffset = offset ?? ServerAnchoredClock.offset;
  if (!ServerAnchoredClock.isAnchored && offset == null) {
    // Without a server anchor there is nothing to reconstruct against. The
    // repair runs on a later pass once an anchor has been observed.
    return null;
  }
  if (!appliedOffset.isNegative) {
    // The device is at or behind the backend, so no local row can carry an
    // instant the server could not have produced.
    return null;
  }

  final now = (anchoredNow ?? ServerAnchoredClock.now)().toUtc();
  final threshold = now.add(_serverFutureTolerance);
  final repaired = <String, int>{};
  final skipped = <String, String>{};

  DateTime correct(DateTime stamped) {
    final reconstructed = stamped.toUtc().add(appliedOffset);
    return reconstructed.isAfter(now) ? now : reconstructed;
  }

  // Each collection is repaired in its own transaction and its own error
  // boundary. A device is running this precisely because it is stalled, so a
  // collection that is unavailable or fails must not discard the progress made
  // on the others.
  Future<void> repairCollection<T>({
    required String label,
    required Future<List<T>> Function() load,
    required bool Function(T) isClean,
    required DateTime Function(T) readUpdatedAt,
    required void Function(T, DateTime) writeUpdatedAt,
    required Future<void> Function(List<T>) save,
  }) async {
    try {
      await isar.writeTxn(() async {
        final candidates = <T>[];
        for (final row in await load()) {
          if (!isClean(row)) continue;
          if (!readUpdatedAt(row).toUtc().isAfter(threshold)) continue;
          writeUpdatedAt(row, correct(readUpdatedAt(row)));
          candidates.add(row);
        }
        if (candidates.isEmpty) return;
        await save(candidates);
        repaired[label] = candidates.length;
      });
    } catch (error) {
      skipped[label] = error.toString();
    }
  }

  {
    await repairCollection<MaintenanceRecord>(
      label: 'maintenance_records',
      load: () => isar.maintenanceRecords.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.maintenanceRecords.putAll(rows),
    );
    await repairCollection<JobTemplate>(
      label: 'job_templates',
      load: () => isar.jobTemplates.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.jobTemplates.putAll(rows),
    );
    await repairCollection<JobExecution>(
      label: 'job_executions',
      load: () => isar.jobExecutions.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.jobExecutions.putAll(rows),
    );
    await repairCollection<JobDiaryEntry>(
      label: 'job_diary_entries',
      load: () => isar.jobDiaryEntrys.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.jobDiaryEntrys.putAll(rows),
    );
    await repairCollection<JobModuleInstance>(
      label: 'job_modules',
      load: () => isar.jobModuleInstances.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.jobModuleInstances.putAll(rows),
    );
    await repairCollection<TemplatePackage>(
      label: 'template_packages',
      load: () => isar.templatePackages.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.templatePackages.putAll(rows),
    );
    await repairCollection<TemplateVersion>(
      label: 'template_versions',
      load: () => isar.templateVersions.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.templateVersions.putAll(rows),
    );
    await repairCollection<TemplatePublishAudit>(
      label: 'template_publish_audits',
      load: () => isar.templatePublishAudits.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.templatePublishAudits.putAll(rows),
    );
    await repairCollection<OperationalDirective>(
      label: 'directives',
      load: () => isar.operationalDirectives.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.operationalDirectives.putAll(rows),
    );
    await repairCollection<AbnormalityType>(
      label: 'abnormality_types',
      load: () => isar.abnormalityTypes.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.abnormalityTypes.putAll(rows),
    );
    await repairCollection<ChargeAbnormality>(
      label: 'charge_abnormalities',
      load: () => isar.chargeAbnormalitys.where().findAll(),
      isClean: (row) => row.isSynced,
      readUpdatedAt: (row) => row.updatedAt,
      writeUpdatedAt: (row, value) => row.updatedAt = value,
      save: (rows) => isar.chargeAbnormalitys.putAll(rows),
    );
  }

  return FutureDatedLocalTimestampRepairReport(
    repairedByCollection: repaired,
    skippedByCollection: skipped,
    appliedOffset: appliedOffset,
  );
}

/// A correctly mirrored server instant cannot sit meaningfully ahead of the
/// anchored server time. The tolerance absorbs the anchor's own conservative
/// bias and the return leg of the request that produced it.
const _serverFutureTolerance = Duration(seconds: 30);

/// Binds the repair to the local store and records a governed audit entry.
///
/// Supplied to [GlobalPullService] as its post-anchor hook, which keeps that
/// service free of any direct local-store dependency.
Future<void> runFutureDatedLocalTimestampRepair({
  required AuditRepository auditRepository,
  required String? actorUid,
}) async {
  final localIsar = Isar.getInstance();
  if (localIsar == null) return;

  final report = await repairFutureDatedLocalTimestamps(localIsar);
  if (report == null || !report.changed) return;

  debugPrint('Re-anchored future-dated local timestamps: $report');

  // A silent rewrite of persisted instants would be indistinguishable from
  // data loss during a later investigation, so the correction is recorded.
  await auditRepository.log(
    AuditEvent(
      entityType: 'sync_local_timestamp_repair',
      entityId: 'future-dated-local-timestamps',
      action: AuditAction.update,
      performedByUid: actorUid ?? 'sync_engine',
      performedByName: 'Sync Engine',
      reason: AuditReason.manualOverride,
      reasonNotes:
          'Clean local rows carried instants the backend could not have '
          'produced, which blocked domain cursor completion. Each was '
          're-anchored onto the server timeline. No version, sync state, '
          'business field or remote document was changed.',
      summary:
          'Re-anchored ${report.repairedRecords} future-dated local timestamps',
      severity: AuditSeverity.medium,
      after: <String, dynamic>{
        'appliedOffsetSeconds': report.appliedOffset.inSeconds,
        'repairedByCollection': report.repairedByCollection,
        if (report.skippedByCollection.isNotEmpty)
          'skippedByCollection': report.skippedByCollection.keys.toList(),
      },
    ),
    syncToRemote: actorUid != null,
  );
}
