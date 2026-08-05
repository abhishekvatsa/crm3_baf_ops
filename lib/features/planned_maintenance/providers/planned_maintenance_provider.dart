// FILE: lib/features/planned_maintenance/providers/planned_maintenance_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../core/persistence/app_database.dart';
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

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

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

class IsarPlannedRepository implements PlannedMaintenanceRepository {
  final AuditRepository _auditRepo;
  final PlannedJobServerCompletionService _serverCompletion;

  IsarPlannedRepository({
    AuditRepository? auditRepository,
    PlannedJobServerCompletionService? serverCompletion,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _serverCompletion =
           serverCompletion ?? PlannedJobServerCompletionService();

  @override
  Future<void> saveTemplate(
    JobTemplate template, {
    required AppUser actor,
  }) async {
    _requireCanSaveLegacyTemplate(actor);
    _normalizeTemplateForUserSave(template, markUnsynced: true);
    await isar.writeTxn(() => isar.jobTemplates.put(template));
  }

  @override
  Future<List<JobTemplate>> getAllTemplates() async {
    return await isar.jobTemplates.filter().isDeletedEqualTo(false).findAll();
  }

  @override
  Stream<List<JobTemplate>> watchAllTemplates({int? limit}) {
    if (limit != null) {
      return isar.jobTemplates
          .filter()
          .isDeletedEqualTo(false)
          .sortByJobName()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobTemplates
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((templates) {
          templates.sort((a, b) => a.jobName.compareTo(b.jobName));
          return templates;
        });
  }

  @override
  Future<JobTemplate?> getTemplateById(dynamic id) async {
    return await isar.jobTemplates.get(id as int);
  }

  @override
  Future<void> deleteTemplate(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanDeleteLegacyTemplate(actor);
    final templateId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final t = await isar.jobTemplates.get(templateId);
      if (t != null && !t.isDeleted) {
        beforeSnapshot = t.toAuditMap();

        t.isDeleted = true;
        if (auditContext != null) {
          // User-initiated delete: full bookkeeping + version bump so
          // updateTemplateFromRemote reconciliation correctly identifies the
          // delete as the winner against concurrent peer edits.
          t.deletedAt = DateTime.now();
          t.deletedByUid = auditContext.performedByUid;
          t.deletedByName = auditContext.performedByName;
          t.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          t.updatedAt = DateTime.now();
          t.version += 1;
        } else {
          // Legacy pull-replay path (until global_pull_service is switched
          // to applyTombstoneFromTemplateRemote). Minimal write only — the
          // remote tombstone metadata is applied separately by
          // updateTemplateFromRemote when this branch is taken.
          t.updatedAt = DateTime.now();
        }
        t.isSynced = false;
        await isar.jobTemplates.put(t);

        afterSnapshot = t.toAuditMap();
        entityIdStr = t.firestoreId ?? t.id.toString();
      }
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityIdStr != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'template',
            entityId: entityIdStr!,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTemplateRemote(
    JobTemplate remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobTemplates
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local template against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remote.deletedAt ?? DateTime.now()
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.jobTemplates.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> saveExecution(
    JobExecution execution, {
    required AppUser actor,
  }) async {
    _requireCanAssignJobExecution(actor);
    _normalizeExecutionForUserSave(execution, markUnsynced: true);
    await isar.writeTxn(() => isar.jobExecutions.put(execution));
  }

  @override
  Future<List<JobExecution>> getAllExecutions() async {
    return await isar.jobExecutions.filter().isDeletedEqualTo(false).findAll();
  }

  @override
  Future<List<JobExecution>> getOpenExecutions() async {
    final rows =
        await isar.jobExecutions
            .filter()
            .isCompletedEqualTo(false)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    return rows.where((execution) => !execution.isCancelled).toList();
  }

  @override
  Future<List<JobExecution>> getExecutionsForAsset(
    AssetType type,
    int number,
  ) async {
    return await isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }

  @override
  Future<List<JobExecution>> getExecutionsForTemplate(
    String templateFirestoreId,
  ) async {
    return await isar.jobExecutions
        .filter()
        .templateFirestoreIdEqualTo(templateFirestoreId)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> deleteExecution(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    if (!actor.canDeleteJobExecution) {
      throw StateError('Not authorized to delete planned job executions.');
    }
    final executionId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityIdStr;

    await isar.writeTxn(() async {
      final e = await isar.jobExecutions.get(executionId);
      if (e != null && !e.isDeleted) {
        beforeSnapshot = e.toAuditMap();

        e.isDeleted = true;
        if (auditContext != null) {
          // User-initiated delete: full bookkeeping + version bump.
          e.deletedAt = DateTime.now();
          e.deletedByUid = auditContext.performedByUid;
          e.deletedByName = auditContext.performedByName;
          e.deleteReason =
              auditContext.reason?.name ?? auditContext.reasonNotes;
          e.updatedAt = DateTime.now();
          e.version += 1;
        } else {
          // Legacy pull-replay path. Minimal write only.
          e.updatedAt = DateTime.now();
        }
        e.isSynced = false;
        await isar.jobExecutions.put(e);

        afterSnapshot = e.toAuditMap();
        entityIdStr = e.firestoreId ?? e.id.toString();
      }
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityIdStr != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'execution',
            entityId: entityIdStr!,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromExecutionRemote(
    JobExecution remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local execution against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remote.deletedAt ?? DateTime.now()
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.jobExecutions.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Stream<List<JobExecution>> watchAllExecutions({int? limit}) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .isDeletedEqualTo(false)
          .sortByUpdatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  @override
  Stream<List<JobExecution>> watchOpenExecutions() {
    return isar.jobExecutions
        .filter()
        .isCompletedEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          final active =
              list.where((execution) => !execution.isCancelled).toList();
          active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return active;
        });
  }

  @override
  Stream<List<JobExecution>> watchExecutionsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .assetNumberEqualTo(number)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .assetNumberEqualTo(number)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Stream<List<JobExecution>> watchExecutionsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    if (limit != null) {
      return isar.jobExecutions
          .filter()
          .assetTypeEqualTo(type)
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.jobExecutions
        .filter()
        .assetTypeEqualTo(type)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((list) {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<List<JobModuleInstance>> _loadModulesForExecution(
    JobExecution execution,
  ) async {
    final executionFirestoreId = _cleanOptionalText(execution.firestoreId);
    final firestoreLinked =
        executionFirestoreId == null
            ? <JobModuleInstance>[]
            : await isar.jobModuleInstances
                .filter()
                .jobExecutionFirestoreIdEqualTo(executionFirestoreId)
                .and()
                .isDeletedEqualTo(false)
                .findAll();
    final localLinked =
        await isar.jobModuleInstances
            .filter()
            .jobExecutionLocalIdEqualTo(execution.id)
            .and()
            .isDeletedEqualTo(false)
            .findAll();

    final resolution = PlannedJobModuleSetResolver.resolve(
      executionFirestoreId: executionFirestoreId,
      executionLocalId: execution.id,
      firestoreLinkedModules: firestoreLinked,
      localLinkedModules: localLinked,
    );

    for (final collision in resolution.ignoredForeignParentCollisions) {
      debugPrint(
        '⚠️ Ignored foreign-parent module during planned-job completion: '
        'module=${collision.moduleTitle}, '
        'moduleFirestoreId=${collision.firestoreId}, '
        'actualExecution=${collision.jobExecutionFirestoreId}, '
        'currentExecution=$executionFirestoreId, '
        'localExecutionId=${collision.jobExecutionLocalId}',
      );
    }

    if (resolution.unresolvedLocalParentModules.isNotEmpty) {
      final ids = resolution.unresolvedLocalParentModules
          .map((module) => module.firestoreId ?? 'local:${module.id}')
          .join(', ');
      throw StateError(
        'Cannot complete planned job: '
        '${resolution.unresolvedLocalParentModules.length} module(s) have an '
        'unresolved local parent identity and are not visible to the canonical '
        'server execution $executionFirestoreId. Reconcile before closure. '
        'Modules: $ids',
      );
    }

    if (resolution.duplicateCanonicalModules.isNotEmpty) {
      final ids = resolution.duplicateCanonicalModules
          .map(
            (module) =>
                '${module.firestoreId ?? 'local:${module.id}'}@isar:${module.id}',
          )
          .join(', ');
      throw StateError(
        'Cannot complete planned job: distinct local rows claim the same '
        'canonical module Firestore id. Resolve the duplicate without '
        'discarding evidence before closure. Rows: $ids',
      );
    }

    return resolution.modules;
  }

  @override
  Future<void> completeExecution(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
  }) async {
    if (!actor.canCompleteJobExecution) {
      throw StateError('You are not authorized to complete planned jobs.');
    }

    final executionId = id as int;
    final local = await isar.jobExecutions.get(executionId);
    if (local == null || local.isDeleted) {
      throw StateError('Planned job execution not found.');
    }
    if (!local.actionsReadResult.isValid) {
      throw StateError(
        'Saved planned-job action evidence needs repair before this job can be completed.',
      );
    }

    final executionFirestoreId = local.firestoreId?.trim();
    if (executionFirestoreId == null || executionFirestoreId.isEmpty) {
      throw StateError(
        'Cannot complete this planned job until it has a Firestore id. '
        'Run sync first, then try completion again.',
      );
    }

    if (!local.isSynced) {
      throw StateError(
        'Cannot complete this planned job until the execution header is synced. '
        'Run sync first so the server validates the current job state.',
      );
    }

    final localModules = await _loadModulesForExecution(local);
    final unsyncedModules =
        localModules.where((module) => !module.isSynced).toList();
    if (unsyncedModules.isNotEmpty) {
      throw StateError(
        'Cannot complete this planned job until all module work is synced '
        '(${unsyncedModules.length} unsynced module(s)). Run sync first.',
      );
    }

    // Local preflight keeps the existing immediate UX, but the Cloud Function
    // is the authority. The server re-loads job_modules and repeats the closure
    // guard before writing isCompleted=true with Admin SDK.
    PlannedJobClosureGuard.assertReady(localModules);

    final remote = await _serverCompletion.completeExecution(
      executionFirestoreId: executionFirestoreId,
      remarks: remarks,
      teamsInvolved: teamsInvolved,
      responses: responses,
      actions: actions,
      expectedCompletionVersion: local.version + 1,
    );

    await isar.writeTxn(() async {
      final current = await isar.jobExecutions.get(executionId);
      if (current == null) return;

      current
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..templatePackageId = _cleanOptionalText(remote.templatePackageId)
        ..templateVersionId = _cleanOptionalText(remote.templateVersionId)
        ..templateVersionNumber = remote.templateVersionNumber
        ..templateVersionLabel = _cleanOptionalText(remote.templateVersionLabel)
        ..templateContentHash = _cleanOptionalText(remote.templateContentHash)
        ..templatePackageCode = _cleanOptionalText(remote.templatePackageCode)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;

      await isar.jobExecutions.put(current);
    });
  }

  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async {
    return await isar.jobTemplates.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markTemplatesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.jobTemplates.getAll(
            ids,
          )).whereType<JobTemplate>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.jobTemplates.putAll(records);
    });
  }

  @override
  Future<void> markTemplatesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.jobTemplates.getAll(
            byId.keys.toList(),
          )).whereType<JobTemplate>().toList();
      final unchanged = <JobTemplate>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.jobTemplates.putAll(unchanged);
    });
  }

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId) async {
    return await isar.jobTemplates
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertTemplateFromRemote(JobTemplate remote) async {
    if (remote.isDeleted) return;
    await isar.writeTxn(() async {
      remote
        ..component = _cleanOptionalText(remote.component)
        ..subsystem = _cleanOptionalText(remote.subsystem)
        ..hierarchyPath = _cleanOptionalStringList(remote.hierarchyPath)
        ..isSynced = true;
      remote.setFields(remote.parsedFields);
      await isar.jobTemplates.put(remote);
    });
  }

  @override
  Future<void> updateTemplateFromRemote(JobTemplate remote) async {
    if (remote.firestoreId == null) return;
    await isar.writeTxn(() async {
      final local =
          await isar.jobTemplates
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced local template against remote tombstone in updateTemplateFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          local.isDeleted = true;
          local.deletedAt = remote.deletedAt ?? DateTime.now();
          local.deletedByUid = remote.deletedByUid;
          local.deletedByName = remote.deletedByName;
          local.deleteReason = remote.deleteReason;
          local.updatedAt = remote.updatedAt;
          local.version = remote.version;
          local.isSynced = true;
          await isar.jobTemplates.put(local);
        }
        return;
      }

      final bool isLocalUnsynced = !local.isSynced;
      final bool isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final bool isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..version = remote.version
        ..jobName = remote.jobName.trim()
        ..description = _cleanOptionalText(remote.description)
        ..applicableAssetType = remote.applicableAssetType
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..component = _cleanOptionalText(remote.component)
        ..subsystem = _cleanOptionalText(remote.subsystem)
        ..hierarchyPath = _cleanOptionalStringList(remote.hierarchyPath)
        ..createdByUid = _cleanOptionalText(remote.createdByUid)
        ..createdByName = _cleanOptionalText(remote.createdByName)
        ..isActive = remote.isActive
        ..isDeprecated = remote.isDeprecated
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;
      local.setFields(remote.parsedFields);
      await isar.jobTemplates.put(local);
    });
  }

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async {
    return await isar.jobExecutions.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markExecutionsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.jobExecutions.getAll(
            ids,
          )).whereType<JobExecution>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.jobExecutions.putAll(records);
    });
  }

  @override
  Future<void> markExecutionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.jobExecutions.getAll(
            byId.keys.toList(),
          )).whereType<JobExecution>().toList();
      final unchanged = <JobExecution>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.jobExecutions.putAll(unchanged);
    });
  }

  @override
  Future<JobExecution?> getExecutionByFirestoreId(String firestoreId) async {
    return await isar.jobExecutions
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<void> insertExecutionFromRemote(JobExecution remote) async {
    if (remote.isDeleted) return;
    await isar.writeTxn(() async {
      remote
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..isSynced = true;
      await isar.jobExecutions.put(remote);
    });
  }

  @override
  Future<void> updateExecutionFromRemote(JobExecution remote) async {
    if (remote.firestoreId == null) return;
    await isar.writeTxn(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();
      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced local execution against remote tombstone in updateExecutionFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          local.isDeleted = true;
          local.deletedAt = remote.deletedAt ?? DateTime.now();
          local.deletedByUid = remote.deletedByUid;
          local.deletedByName = remote.deletedByName;
          local.deleteReason = remote.deleteReason;
          local.updatedAt = remote.updatedAt;
          local.version = remote.version;
          local.isSynced = true;
          await isar.jobExecutions.put(local);
        }
        return;
      }

      final bool isLocalUnsynced = !local.isSynced;
      final bool isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final bool isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      local
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..templatePackageId = _cleanOptionalText(remote.templatePackageId)
        ..templateVersionId = _cleanOptionalText(remote.templateVersionId)
        ..templateVersionNumber = remote.templateVersionNumber
        ..templateVersionLabel = _cleanOptionalText(remote.templateVersionLabel)
        ..templateContentHash = _cleanOptionalText(remote.templateContentHash)
        ..templatePackageCode = _cleanOptionalText(remote.templatePackageCode)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;
      await isar.jobExecutions.put(local);
    });
  }

  @override
  Future<void> forceRebaseExecutionFromRemote(
    JobExecution remote, {
    String? reason,
  }) async {
    if (remote.firestoreId == null) return;

    await isar.writeTxn(() async {
      final local =
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      local
        ..version = remote.version
        ..templateFirestoreId = remote.templateFirestoreId
        ..templateName = _cleanOptionalText(remote.templateName)
        ..assetType = remote.assetType
        ..assetNumber = remote.assetNumber
        ..isCompleted = remote.isCompleted
        ..assignedByUid = _cleanOptionalText(remote.assignedByUid)
        ..assignedByName = _cleanOptionalText(remote.assignedByName)
        ..assignedAgencies = _cleanStringList(remote.assignedAgencies)
        ..completedByUid = _cleanOptionalText(remote.completedByUid)
        ..completedByName = _cleanOptionalText(remote.completedByName)
        ..remarks = _cleanOptionalText(remote.remarks)
        ..teamsInvolved = _cleanStringList(remote.teamsInvolved)
        ..chargeNoAtEvent = remote.chargeNoAtEvent
        ..responsesJson = remote.responsesJson
        ..actionsJson = remote.actionsJson
        ..metadataJson = _cleanOptionalText(remote.metadataJson)
        ..isDeleted = remote.isDeleted
        ..deletedAt = remote.deletedAt
        ..deletedByUid = _cleanOptionalText(remote.deletedByUid)
        ..deletedByName = _cleanOptionalText(remote.deletedByName)
        ..deleteReason = _cleanOptionalText(remote.deleteReason)
        ..createdAt = remote.createdAt
        ..completedAt = remote.completedAt
        ..updatedAt = remote.updatedAt
        ..isSynced = true;

      await isar.jobExecutions.put(local);
    });

    if (reason != null && reason.trim().isNotEmpty) {
      debugPrint(
        '🛡️ Rebased local job execution from remote canonical state: '
        'firestoreId=${remote.firestoreId}, reason=$reason',
      );
    }
  }

  @override
  Future<PaginatedTemplateResult> getUpdatedTemplates({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateResult(records: [], lastDoc: null);
  }

  @override
  Future<PaginatedExecutionResult> getUpdatedExecutions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedExecutionResult(records: [], lastDoc: null);
  }

  @override
  Future<List<JobTemplate>> getTemplatesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <JobTemplate>[];
    for (final fid in ids) {
      final t =
          await isar.jobTemplates.filter().firestoreIdEqualTo(fid).findFirst();
      if (t != null) results.add(t);
    }
    return results;
  }

  @override
  Future<void> batchUpsertTemplates(List<JobTemplate> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.jobTemplates.put(r);
      }
    });
  }

  @override
  Future<List<JobExecution>> getExecutionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobExecution>[];
    for (final fid in ids) {
      final e =
          await isar.jobExecutions.filter().firestoreIdEqualTo(fid).findFirst();
      if (e != null) results.add(e);
    }
    return results;
  }

  @override
  Future<void> batchUpsertExecutions(List<JobExecution> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.jobExecutions.put(r);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class FirestorePlannedRepository implements PlannedMaintenanceRepository {
  final AuditRepository _auditRepo;
  final PlannedJobServerCompletionService _serverCompletion;

  FirestorePlannedRepository({
    AuditRepository? auditRepository,
    PlannedJobServerCompletionService? serverCompletion,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _serverCompletion =
           serverCompletion ?? PlannedJobServerCompletionService();

  final _templates = FirebaseFirestore.instance.collection('job_templates');
  final _executions = FirebaseFirestore.instance.collection('job_executions');

  Map<String, dynamic>? _sanitizeForAudit(Map<String, dynamic>? data) {
    if (data == null) return null;
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is FieldValue) {
        sanitized[key] = value.toString();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  @override
  Stream<List<JobTemplate>> watchAllTemplates({int? limit}) {
    var query = _templates
        .where('isDeleted', isEqualTo: false)
        .orderBy('jobName');

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobTemplate.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchAllExecutions({int? limit}) {
    var query = _executions
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchOpenExecutions() {
    return _executions
        .where('isCompleted', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
                  .where((execution) => !execution.isCancelled)
                  .toList(),
        );
  }

  @override
  Stream<List<JobExecution>> watchExecutionsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _executions
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Stream<List<JobExecution>> watchExecutionsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _executions
        .where('assetType', isEqualTo: type.name)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> completeExecution(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
  }) async {
    if (!actor.canCompleteJobExecution) {
      throw StateError('You are not authorized to complete planned jobs.');
    }

    final docId = id as String;

    // M6 full enforcement: direct client writes to job_executions completion
    // are denied by Firestore rules. The callable function re-loads modules,
    // applies the closure guard server-side, writes the completion with Admin
    // SDK, and emits the canonical audit event.
    await _serverCompletion.completeExecution(
      executionFirestoreId: docId,
      remarks: remarks,
      teamsInvolved: teamsInvolved,
      responses: responses,
      actions: actions,
    );
  }

  @override
  Future<List<JobExecution>> getExecutionsForTemplate(
    String templateFirestoreId,
  ) async {
    final snap =
        await _executions
            .where('templateFirestoreId', isEqualTo: templateFirestoreId)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> saveTemplate(
    JobTemplate template, {
    required AppUser actor,
  }) async {
    _requireCanSaveLegacyTemplate(actor);
    if (template.firestoreId == null) throw Exception('firestoreId required');
    _normalizeTemplateForUserSave(template, markUnsynced: false);
    await _templates
        .doc(template.firestoreId)
        .set(template.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<JobTemplate>> getAllTemplates() async {
    final snap = await _templates.where('isDeleted', isEqualTo: false).get();
    return snap.docs
        .map((doc) => JobTemplate.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<JobTemplate?> getTemplateById(dynamic id) async {
    final doc = await _templates.doc(id as String).get();
    if (!doc.exists) return null;
    return JobTemplate.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> deleteTemplate(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanDeleteLegacyTemplate(actor);
    final docId = id as String;

    final beforeDoc = await _templates.doc(docId).get();
    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'updatedAt': now,
      'version': nextVersion,
    };
    if (auditContext != null) {
      updateData['deletedByUid'] = auditContext.performedByUid;
      updateData['deletedByName'] = auditContext.performedByName;
      updateData['deleteReason'] =
          auditContext.reason?.name ?? auditContext.reasonNotes;
    }
    await _templates.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'template',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTemplateRemote(
    JobTemplate remote,
  ) async {
    // No-op on web. Firestore is the source of truth and is observed via
    // .snapshots() — there is no separate "local store" to tombstone.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> saveExecution(
    JobExecution execution, {
    required AppUser actor,
  }) async {
    _requireCanAssignJobExecution(actor);
    if (execution.firestoreId == null) throw Exception('firestoreId required');
    _normalizeExecutionForUserSave(execution, markUnsynced: false);
    await _executions
        .doc(execution.firestoreId)
        .set(execution.toClientWritableMap(), SetOptions(merge: true));
  }

  @override
  Future<List<JobExecution>> getAllExecutions() async {
    final snap = await _executions.where('isDeleted', isEqualTo: false).get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<JobExecution>> getOpenExecutions() async {
    final snap =
        await _executions
            .where('isCompleted', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .where((execution) => !execution.isCancelled)
        .toList();
  }

  @override
  Future<List<JobExecution>> getExecutionsForAsset(
    AssetType type,
    int number,
  ) async {
    final snap =
        await _executions
            .where('assetType', isEqualTo: type.name)
            .where('assetNumber', isEqualTo: number)
            .where('isDeleted', isEqualTo: false)
            .get();
    return snap.docs
        .map((doc) => JobExecution.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> deleteExecution(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    if (!actor.canDeleteJobExecution) {
      throw StateError('Not authorized to delete planned job executions.');
    }
    final docId = id as String;

    final beforeDoc = await _executions.doc(docId).get();
    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'updatedAt': now,
      'version': nextVersion,
    };
    if (auditContext != null) {
      updateData['deletedByUid'] = auditContext.performedByUid;
      updateData['deletedByName'] = auditContext.performedByName;
      updateData['deleteReason'] =
          auditContext.reason?.name ?? auditContext.reasonNotes;
    }
    await _executions.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'execution',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromExecutionRemote(
    JobExecution remote,
  ) async {
    // No-op on web. See applyTombstoneFromTemplateRemote.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async => [];

  @override
  Future<void> markTemplatesSynced(List<int> ids) async {}

  @override
  Future<void> markTemplatesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId) async {
    final doc = await _templates.doc(firestoreId).get();
    if (!doc.exists) return null;
    return JobTemplate.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> insertTemplateFromRemote(JobTemplate remote) async {}

  @override
  Future<void> updateTemplateFromRemote(JobTemplate remote) async {}

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async => [];

  @override
  Future<void> markExecutionsSynced(List<int> ids) async {}

  @override
  Future<void> markExecutionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<JobExecution?> getExecutionByFirestoreId(String firestoreId) async {
    final doc = await _executions.doc(firestoreId).get();
    if (!doc.exists) return null;
    return JobExecution.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> insertExecutionFromRemote(JobExecution remote) async {}

  @override
  Future<void> updateExecutionFromRemote(JobExecution remote) async {}

  @override
  Future<void> forceRebaseExecutionFromRemote(
    JobExecution remote, {
    String? reason,
  }) async {}

  @override
  Future<PaginatedTemplateResult> getUpdatedTemplates({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-template pull has no server upper bound.',
        reasonCode: 'job-template-server-anchor-missing',
      );
    }
    var q = globalPullServerWindowQuery(
      _templates,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.limit(limit).get();
    return PaginatedTemplateResult(
      records:
          snap.docs.map((d) => JobTemplate.fromMap(d.data(), d.id)).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedExecutionResult> getUpdatedExecutions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-execution pull has no server upper bound.',
        reasonCode: 'job-execution-server-anchor-missing',
      );
    }
    var q = globalPullServerWindowQuery(
      _executions,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.limit(limit).get();
    return PaginatedExecutionResult(
      records:
          snap.docs.map((d) => JobExecution.fromMap(d.data(), d.id)).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<JobTemplate>> getTemplatesByFirestoreIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <JobTemplate>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _templates.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobTemplate.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertTemplates(List<JobTemplate> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      if (r.firestoreId != null) {
        batch.set(
          _templates.doc(r.firestoreId),
          r.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<List<JobExecution>> getExecutionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobExecution>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _executions.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobExecution.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertExecutions(List<JobExecution> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      if (r.firestoreId != null) {
        batch.set(
          _executions.doc(r.firestoreId),
          r.toClientWritableMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
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
