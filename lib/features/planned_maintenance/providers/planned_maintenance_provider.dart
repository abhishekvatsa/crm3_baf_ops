// FILE: lib/features/planned_maintenance/providers/planned_maintenance_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore show Query;
import 'package:isar/isar.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/utils/combined_record_stream.dart';
import '../data/job_template_model.dart';
import '../data/job_module_model.dart';
import '../domain/planned_job_closure_guard.dart';
import '../domain/planned_job_module_set_resolver.dart';
import '../services/planned_job_server_completion_service.dart';
import '../models/component_action_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';

part 'planned_maintenance_provider.local.dart';
part 'planned_maintenance_provider.remote.dart';

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

bool jobExecutionOverlapsPeriod(
  JobExecution execution,
  DateTime startInclusive,
  DateTime endExclusive,
) =>
    execution.createdAt.isBefore(endExclusive) &&
    ((execution.completedAt ?? execution.cancelledAt) == null ||
        (execution.completedAt ?? execution.cancelledAt)!.isAfter(
          startInclusive,
        ));

// ─────────────────────────────────────────────────────────────
// NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<String> _cleanStringList(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

List<String>? _cleanOptionalStringList(List<String>? values) {
  if (values == null) return null;
  final cleaned = _cleanStringList(values);
  return cleaned.isEmpty ? null : cleaned;
}

void _normalizeTemplateForUserSave(
  JobTemplate template, {
  required bool markUnsynced,
}) {
  final now = DateTime.now();

  template
    ..jobName = template.jobName.trim()
    ..description = _cleanOptionalText(template.description)
    ..assignedAgencies = _cleanStringList(template.assignedAgencies)
    ..component = _cleanOptionalText(template.component)
    ..subsystem = _cleanOptionalText(template.subsystem)
    ..hierarchyPath = _cleanOptionalStringList(template.hierarchyPath)
    ..assetHierarchyRefJson = _cleanOptionalText(template.assetHierarchyRefJson)
    ..createdByUid = _cleanOptionalText(template.createdByUid)
    ..createdByName = _cleanOptionalText(template.createdByName)
    ..deletedByUid = _cleanOptionalText(template.deletedByUid)
    ..deletedByName = _cleanOptionalText(template.deletedByName)
    ..deleteReason = _cleanOptionalText(template.deleteReason)
    ..metadataJson = _cleanOptionalText(template.metadataJson)
    ..updatedAt = now
    ..version += 1;

  // If a UI screen mutates the ignored `fields` list directly, make sure the
  // persisted Isar/Firestore source-of-truth (`fieldsJson`) is rebuilt before
  // saving. This protects mobile persistence until all UI screens are cleaned.
  final fieldsForPersistence = template.parsedFields;
  template.setFields(fieldsForPersistence);

  if (markUnsynced) {
    template.isSynced = false;
  }
}

void _normalizeExecutionForUserSave(
  JobExecution execution, {
  required bool markUnsynced,
}) {
  final now = DateTime.now();

  execution
    ..templateName = _cleanOptionalText(execution.templateName)
    ..templatePackageId = _cleanOptionalText(execution.templatePackageId)
    ..templateVersionId = _cleanOptionalText(execution.templateVersionId)
    ..templateVersionLabel = _cleanOptionalText(execution.templateVersionLabel)
    ..templateContentHash = _cleanOptionalText(execution.templateContentHash)
    ..templatePackageCode = _cleanOptionalText(execution.templatePackageCode)
    ..assignedByUid = _cleanOptionalText(execution.assignedByUid)
    ..assignedByName = _cleanOptionalText(execution.assignedByName)
    ..assignedAgencies = _cleanStringList(execution.assignedAgencies)
    ..completedByUid = _cleanOptionalText(execution.completedByUid)
    ..completedByName = _cleanOptionalText(execution.completedByName)
    ..remarks = _cleanOptionalText(execution.remarks)
    ..teamsInvolved = _cleanStringList(execution.teamsInvolved)
    ..deletedByUid = _cleanOptionalText(execution.deletedByUid)
    ..deletedByName = _cleanOptionalText(execution.deletedByName)
    ..deleteReason = _cleanOptionalText(execution.deleteReason)
    ..metadataJson = _cleanOptionalText(execution.metadataJson)
    ..updatedAt = now
    ..version += 1;

  if (markUnsynced) {
    execution.isSynced = false;
  }
}

void _requireCanSaveLegacyTemplate(AppUser actor) {
  if (!actor.canCreateLegacyJobTemplate) {
    throw StateError('Only Admin/SI can create or edit legacy job templates.');
  }
}

void _requireCanDeleteLegacyTemplate(AppUser actor) {
  if (!actor.canDeleteLegacyJobTemplate) {
    throw StateError('Only Admin can delete legacy job templates.');
  }
}

void _requireCanAssignJobExecution(AppUser actor) {
  if (!actor.canAssignJobExecution) {
    throw StateError('Not authorized to assign planned jobs.');
  }
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedTemplateResult {
  final List<JobTemplate> records;
  final DocumentSnapshot? lastDoc;
  PaginatedTemplateResult({required this.records, this.lastDoc});
}

class PaginatedExecutionResult {
  final List<JobExecution> records;
  final DocumentSnapshot? lastDoc;
  PaginatedExecutionResult({required this.records, this.lastDoc});
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class PlannedMaintenanceRepository {
  Future<void> saveTemplate(JobTemplate template, {required AppUser actor});
  Future<List<JobTemplate>> getAllTemplates();
  Future<JobTemplate?> getTemplateById(dynamic id);
  Future<void> deleteTemplate(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  /// Applies a tombstone received from a remote pull. Idempotent. Copies remote
  /// metadata verbatim, marks the local row clean only when the tombstone is
  /// actually applied, and returns a structured outcome so pull orchestration
  /// can surface preserved dirty-local conflicts instead of counting them as
  /// successful deletes. To be called by global_pull_service in place of
  /// deleteTemplate(id) for pulled deletions.
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTemplateRemote(
    JobTemplate remote,
  );

  /// Reactive stream of non-deleted job templates. Fires immediately with
  /// the current value, then on every local change. Note: backed by
  /// getAllTemplates() semantics (only filters isDeleted), not isActive.
  Stream<List<JobTemplate>> watchAllTemplates({int? limit});

  Future<void> saveExecution(JobExecution execution, {required AppUser actor});
  Future<List<JobExecution>> getAllExecutions();
  Future<List<JobExecution>> getOpenExecutions();
  Future<List<JobExecution>> getExecutionsForAsset(AssetType type, int number);
  Future<List<JobExecution>> getExecutionsForTemplate(
    String templateFirestoreId,
  );
  Future<void> deleteExecution(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  /// Applies a tombstone received from a remote pull. See
  /// applyTombstoneFromTemplateRemote for contract details.
  Future<RemoteTombstoneApplyResult> applyTombstoneFromExecutionRemote(
    JobExecution remote,
  );

  /// Returns a stream of all non-deleted job executions sorted by updatedAt.
  Stream<List<JobExecution>> watchAllExecutions({int? limit});

  Stream<List<JobExecution>> watchExecutionsOverlappingPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream<List<JobExecution>>.error(
        ArgumentError('Report start must precede report end.'),
      );
    }
    return watchAllExecutions().map(
      (records) => records
          .where(
            (record) => jobExecutionOverlapsPeriod(
              record,
              startInclusive,
              endExclusive,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Returns a stream of active (assigned) job executions.
  Stream<List<JobExecution>> watchOpenExecutions();

  /// Returns a stream of job executions for a specific industrial asset.
  Stream<List<JobExecution>> watchExecutionsForAsset(
    AssetType type,
    int number, {
    int? limit,
  });

  /// Reactive stream of non-deleted job executions scoped to an asset type.
  /// Used by fleet reporting to avoid loading unrelated asset families.
  Stream<List<JobExecution>> watchExecutionsByAssetType(
    AssetType type, {
    int? limit,
  });

  Future<void> completeExecution(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
  });

  Future<List<JobTemplate>> getUnsyncedTemplates();
  Future<void> markTemplatesSynced(List<int> ids);
  Future<void> markTemplatesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId);
  Future<void> insertTemplateFromRemote(JobTemplate remote);
  Future<void> updateTemplateFromRemote(JobTemplate remote);

  Future<List<JobExecution>> getUnsyncedExecutions();
  Future<void> markExecutionsSynced(List<int> ids);
  Future<void> markExecutionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  );
  Future<JobExecution?> getExecutionByFirestoreId(String firestoreId);
  Future<void> insertExecutionFromRemote(JobExecution remote);
  Future<void> updateExecutionFromRemote(JobExecution remote);

  /// Forcefully rebases a dirty local execution from the remote canonical copy.
  /// Used only by sync repair after Firestore rules reject an impossible
  /// local tombstone push and the local snapshot has been preserved in audit.
  Future<void> forceRebaseExecutionFromRemote(
    JobExecution remote, {
    String? reason,
  });

  Future<PaginatedTemplateResult> getUpdatedTemplates({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<PaginatedExecutionResult> getUpdatedExecutions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<List<JobTemplate>> getTemplatesByFirestoreIds(List<String> ids);
  Future<void> batchUpsertTemplates(List<JobTemplate> records);
  Future<List<JobExecution>> getExecutionsByFirestoreIds(List<String> ids);
  Future<void> batchUpsertExecutions(List<JobExecution> records);
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

final plannedJobServerCompletionServiceProvider =
    Provider<PlannedJobServerCompletionService>((ref) {
      return PlannedJobServerCompletionService();
    });

final isarPlannedRepo = Provider<IsarPlannedRepository>((ref) {
  return IsarPlannedRepository(
    auditRepository: ref.read(auditRepositoryProvider),
    serverCompletion: ref.read(plannedJobServerCompletionServiceProvider),
  );
});
final firestorePlannedRepo = Provider<FirestorePlannedRepository>((ref) {
  return FirestorePlannedRepository(
    auditRepository: ref.read(auditRepositoryProvider),
    serverCompletion: ref.read(plannedJobServerCompletionServiceProvider),
  );
});

final plannedRepositoryProvider = Provider<PlannedMaintenanceRepository>((ref) {
  return kIsWeb ? ref.watch(firestorePlannedRepo) : ref.watch(isarPlannedRepo);
});

// 🔥 CONVERTED: From FutureProvider to StreamProvider for live UI refresh
// after sync pulls write to local Isar / remote Firestore.
// Note: still backed by getAllTemplates() semantics (only filters isDeleted),
// matching prior behavior. Active-vs-inactive filtering is a separate concern.
final activeTemplatesProvider = StreamProvider<List<JobTemplate>>((ref) {
  return ref.watch(plannedRepositoryProvider).watchAllTemplates();
});

final openExecutionsProvider = StreamProvider<List<JobExecution>>((ref) {
  return ref.watch(plannedRepositoryProvider).watchOpenExecutions();
});

/// Completed and cancelled executions retained as closed operational dossiers.
/// The repository excludes tombstones and returns newest updates first.
const int _closedExecutionSourceLimit = 500;
final closedExecutionsProvider = StreamProvider<List<JobExecution>>((ref) {
  return ref
      .watch(plannedRepositoryProvider)
      .watchAllExecutions(limit: _closedExecutionSourceLimit)
      .map(
        (executions) => executions
            .where(
              (execution) => execution.isCompleted || execution.isCancelled,
            )
            .toList(growable: false),
      );
});

/// Home badge count provider. On mobile/desktop it avoids materialising the
/// full open-execution list just to compute the badge count. List screens should
/// keep using [openExecutionsProvider].
final openExecutionCountProvider = StreamProvider<int>((ref) {
  if (kIsWeb) {
    return ref
        .watch(plannedRepositoryProvider)
        .watchOpenExecutions()
        .map((executions) => executions.length)
        .distinct();
  }

  Future<int> countOpenExecutions() async {
    final rows =
        await isar.jobExecutions
            .filter()
            .isCompletedEqualTo(false)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    return rows.where((execution) => !execution.isCancelled).length;
  }

  return isar.jobExecutions
      .filter()
      .isCompletedEqualTo(false)
      .and()
      .isDeletedEqualTo(false)
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => countOpenExecutions())
      .distinct();
});
