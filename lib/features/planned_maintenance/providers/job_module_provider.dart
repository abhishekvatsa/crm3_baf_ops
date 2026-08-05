// FILE: lib/features/planned_maintenance/providers/job_module_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../../core/persistence/app_database.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../data/job_module_model.dart';
import '../domain/planned_job_module_set_resolver.dart';
import '../services/runtime_job_module_population_service.dart';
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

/// Compares only the canonical client-owned Firestore payload.
///
/// This is the lost-response/idempotent-replay boundary for first remote
/// acceptance: if the callable committed but the response was lost, the next
/// sync sees an existing remote document whose client payload is already exact.
/// Treating that state as satisfied avoids a same-version direct update that
/// Firestore rules would correctly reject.
bool jobModuleClientSnapshotsEquivalentForSync(
  JobModuleInstance local,
  JobModuleInstance remote,
) => jsonEncode(local.toMap()) == jsonEncode(remote.toMap());

// ─────────────────────────────────────────────────────────────
// NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _cleanRequiredText(String? value, String fallback) {
  final cleaned = _cleanOptionalText(value);
  return cleaned ?? fallback;
}

List<String> _cleanStringList(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

DateTime? _readCreatedAtSafely(JobModuleInstance module) {
  try {
    return module.createdAt;
  } catch (_) {
    return null;
  }
}

DateTime? _readUpdatedAtSafely(JobModuleInstance module) {
  try {
    return module.updatedAt;
  } catch (_) {
    return null;
  }
}

String? _readModuleTitleSafely(JobModuleInstance module) {
  try {
    return module.moduleTitle;
  } catch (_) {
    return null;
  }
}

String _newModuleFirestoreId() {
  return FirebaseFirestore.instance.collection('job_modules').doc().id;
}

void _requireApprovedActor(AppUser actor, String actionLabel) {
  if (!actor.isApproved) {
    throw StateError('Not authorized to $actionLabel: user is not approved.');
  }
}

void _requireCanSubmitModule(AppUser actor, JobModuleInstance module) {
  _requireApprovedActor(actor, 'submit this module');
  if (!actor.canSubmitJobModule(module.discipline.name)) {
    throw StateError('Not authorized to submit this module.');
  }
}

enum ModuleModerationAction { accept, reopen, markNotApplicable, softDelete }

String _moduleModerationActionLabel(ModuleModerationAction action) {
  switch (action) {
    case ModuleModerationAction.accept:
      return 'accept this module';
    case ModuleModerationAction.reopen:
      return 'reopen this module';
    case ModuleModerationAction.markNotApplicable:
      return 'mark this module not applicable';
    case ModuleModerationAction.softDelete:
      return 'delete this module';
  }
}

void _requireCanModerateModule(AppUser actor, ModuleModerationAction action) {
  final actionLabel = _moduleModerationActionLabel(action);
  _requireApprovedActor(actor, actionLabel);

  final allowed = switch (action) {
    ModuleModerationAction.accept => actor.canAcceptJobModule,
    ModuleModerationAction.reopen => actor.canReopenJobModule,
    ModuleModerationAction.markNotApplicable =>
      actor.canMarkJobModuleNotApplicable,
    ModuleModerationAction.softDelete => actor.isModuleLifecycleSupervisor,
  };

  if (!allowed) {
    throw StateError('Not authorized to $actionLabel.');
  }
}

void _requireCanAddModuleDuringExecution(AppUser actor) {
  _requireApprovedActor(actor, 'add process modules to active jobs');
  if (!actor.canAddJobModuleDuringExecution) {
    throw StateError('Not authorized to add process modules to active jobs.');
  }
}

bool _isEmergencyManualSeedModule(JobModuleInstance module) {
  final templateVersionId =
      module.templateVersionId?.trim().toLowerCase() ?? '';
  final templatePackageId =
      module.templatePackageId?.trim().toLowerCase() ?? '';
  final templateModuleId = module.templateModuleId?.trim().toLowerCase() ?? '';

  return templateVersionId.startsWith('seed:') ||
      templatePackageId.startsWith('seed:') ||
      templateModuleId.startsWith('seed:');
}

bool _requiresElevatedRuntimeAddControl(JobModuleInstance module) {
  if (!module.addedDuringExecution) return false;

  return module.requiredForClosure ||
      module.discipline == JobModuleDiscipline.shared ||
      module.discipline == JobModuleDiscipline.safety ||
      module.safetyClass != JobModuleSafetyClass.normal;
}

bool _canConfirmElevatedRuntimeModuleAdd(AppUser actor) {
  return actor.isAdmin ||
      actor.isSI ||
      actor.isContractSupervisor ||
      actor.isShiftSupervisor;
}

void _requireRuntimeModuleAddControl(AppUser actor, JobModuleInstance module) {
  if (!_requiresElevatedRuntimeAddControl(module)) return;
  if (_canConfirmElevatedRuntimeModuleAdd(actor)) return;

  final source =
      _isEmergencyManualSeedModule(module)
          ? 'Emergency/manual seed catalogue'
          : 'published governed catalogue';
  throw StateError(
    'Supervisor/Admin/SI confirmation is required to add safety-critical, '
    'shared or closure-critical modules from the $source.',
  );
}

void _requireCanSaveModuleWork(
  AppUser actor,
  JobModuleInstance module,
) {
  _requireApprovedActor(actor, 'save module work');
  if (!actor.canSaveJobModuleWorkFor(module.discipline.name)) {
    throw StateError(
      'Not authorized to save ${module.discipline.name} module work.',
    );
  }
}

void _requireValidModulePersistedEvidence(JobModuleInstance module) {
  if (!module.fieldDefinitionsReadResult.isValid) {
    throw StateError(
      'Saved module field definitions need repair before this module can be changed.',
    );
  }
  if (!module.responsesReadResult.isValid) {
    throw StateError(
      'Saved module responses need repair before this module can be changed.',
    );
  }
  if (!module.actionsReadResult.isValid) {
    throw StateError(
      'Saved module action evidence needs repair before this module can be changed.',
    );
  }
}

void _requireOpenForWork(JobModuleInstance module, String actionLabel) {
  _requireValidModulePersistedEvidence(module);
  if (!module.isOpenForWork) {
    throw StateError('Only open modules can be used to $actionLabel.');
  }
}

void _requireSubmitted(JobModuleInstance module, String actionLabel) {
  _requireValidModulePersistedEvidence(module);
  if (module.status != JobModuleStatus.submitted) {
    throw StateError('Only submitted modules can be used to $actionLabel.');
  }
}

void _requireReopenable(JobModuleInstance module) {
  _requireValidModulePersistedEvidence(module);
  final reopenable =
      module.status == JobModuleStatus.submitted ||
      module.status == JobModuleStatus.accepted ||
      module.status == JobModuleStatus.notApplicable;
  if (!reopenable) {
    throw StateError(
      'Only submitted, accepted, or not-applicable modules can be reopened.',
    );
  }
}

void _normaliseModuleForUserSave(
  JobModuleInstance module, {
  required bool markUnsynced,
  AuditContext? auditContext,
  bool preserveCreatedAt = true,
  bool incrementVersion = false,
}) {
  _requireValidModulePersistedEvidence(module);
  final now = DateTime.now();

  module.firestoreId ??= _newModuleFirestoreId();

  final existingCreatedAt = _readCreatedAtSafely(module);
  module.createdAt =
      preserveCreatedAt && existingCreatedAt != null ? existingCreatedAt : now;

  final existingUpdatedAt = _readUpdatedAtSafely(module);
  if (existingUpdatedAt == null) {
    module.updatedAt = now;
  }

  if (auditContext != null) {
    module.createdByUid ??= auditContext.performedByUid;
    module.createdByName ??= auditContext.performedByName;
    module.updatedByUid = auditContext.performedByUid;
    module.updatedByName = auditContext.performedByName;
  }

  module
    ..jobExecutionFirestoreId = _cleanOptionalText(
      module.jobExecutionFirestoreId,
    )
    ..templateFirestoreId = _cleanOptionalText(module.templateFirestoreId)
    ..templateName = _cleanOptionalText(module.templateName)
    ..templatePackageId = _cleanOptionalText(module.templatePackageId)
    ..templateVersionId = _cleanOptionalText(module.templateVersionId)
    ..templateModuleId = _cleanOptionalText(module.templateModuleId)
    ..moduleCode = _cleanOptionalText(module.moduleCode)
    ..moduleSnapshotJson = _cleanRequiredText(module.moduleSnapshotJson, '{}')
    ..fieldDefinitionsJson = _cleanRequiredText(
      module.fieldDefinitionsJson,
      '[]',
    )
    ..pairedEquipmentJson = _cleanOptionalText(module.pairedEquipmentJson)
    ..moduleTitle = _cleanRequiredText(
      _readModuleTitleSafely(module),
      'Untitled module',
    )
    ..moduleDescription = _cleanOptionalText(module.moduleDescription)
    ..functionalSection = _cleanOptionalText(module.functionalSection)
    ..componentGroup = _cleanOptionalText(module.componentGroup)
    ..subsystem = _cleanOptionalText(module.subsystem)
    ..targetRef = _cleanOptionalText(module.targetRef)
    ..targetRefs = _cleanStringList(module.targetRefs)
    ..procedureRefs = _cleanStringList(module.procedureRefs)
    ..safetyConfirmations = _cleanStringList(module.safetyConfirmations)
    ..tags = _cleanStringList(module.tags)
    ..operationalStatePreconditions = _cleanStringList(
      module.operationalStatePreconditions,
    )
    ..responsesJson = _cleanRequiredText(module.responsesJson, '[]')
    ..actionsJson = _cleanRequiredText(module.actionsJson, '[]')
    ..draftNote = _cleanOptionalText(module.draftNote)
    ..submissionNote = _cleanOptionalText(module.submissionNote)
    ..acceptanceNote = _cleanOptionalText(module.acceptanceNote)
    ..reopenReason = _cleanOptionalText(module.reopenReason)
    ..notApplicableReason = _cleanOptionalText(module.notApplicableReason)
    ..pendingIssue = _cleanOptionalText(module.pendingIssue)
    ..addedByUid = _cleanOptionalText(module.addedByUid)
    ..addedByName = _cleanOptionalText(module.addedByName)
    ..addReason = _cleanOptionalText(module.addReason)
    ..createdByUid = _cleanOptionalText(module.createdByUid)
    ..createdByName = _cleanOptionalText(module.createdByName)
    ..updatedByUid = _cleanOptionalText(module.updatedByUid)
    ..updatedByName = _cleanOptionalText(module.updatedByName)
    ..submittedByUid = _cleanOptionalText(module.submittedByUid)
    ..submittedByName = _cleanOptionalText(module.submittedByName)
    ..acceptedByUid = _cleanOptionalText(module.acceptedByUid)
    ..acceptedByName = _cleanOptionalText(module.acceptedByName)
    ..reopenedByUid = _cleanOptionalText(module.reopenedByUid)
    ..reopenedByName = _cleanOptionalText(module.reopenedByName)
    ..notApplicableByUid = _cleanOptionalText(module.notApplicableByUid)
    ..notApplicableByName = _cleanOptionalText(module.notApplicableByName)
    ..deletedByUid = _cleanOptionalText(module.deletedByUid)
    ..deletedByName = _cleanOptionalText(module.deletedByName)
    ..deleteReason = _cleanOptionalText(module.deleteReason)
    ..metadataJson = _cleanOptionalText(module.metadataJson)
    ..updatedAt = now;

  if (_cleanOptionalText(module.jobExecutionFirestoreId) != null) {
    module.jobExecutionLocalId = null;
  }

  if (module.addedDuringExecution && module.addedAt == null) {
    module.addedAt = now;
    module.addedByUid ??= auditContext?.performedByUid;
    module.addedByName ??= auditContext?.performedByName;
  }

  if (incrementVersion) {
    module.version += 1;
  }

  if (markUnsynced) {
    module.isSynced = false;
  }
}

void _copyRemoteModuleIntoLocal(
  JobModuleInstance local,
  JobModuleInstance remote,
) {
  local
    ..firestoreId = remote.firestoreId
    ..isSynced = true
    ..version = remote.version
    ..jobExecutionFirestoreId = remote.jobExecutionFirestoreId
    ..jobExecutionLocalId = null
    ..templateFirestoreId = remote.templateFirestoreId
    ..templateName = remote.templateName
    ..templatePackageId = remote.templatePackageId
    ..templateVersionId = remote.templateVersionId
    ..templateModuleId = remote.templateModuleId
    ..moduleCode = remote.moduleCode
    ..moduleSnapshotJson = remote.moduleSnapshotJson
    ..fieldDefinitionsJson = remote.fieldDefinitionsJson
    ..assetType = remote.assetType
    ..assetNumber = remote.assetNumber
    ..chargeNoAtEvent = remote.chargeNoAtEvent
    ..pairedEquipmentJson = remote.pairedEquipmentJson
    ..moduleTitle = remote.moduleTitle
    ..moduleDescription = remote.moduleDescription
    ..status = remote.status
    ..useMode = remote.useMode
    ..discipline = remote.discipline
    ..safetyClass = remote.safetyClass
    ..isRequired = remote.isRequired
    ..requiredForClosure = remote.requiredForClosure
    ..addedDuringExecution = remote.addedDuringExecution
    ..displayOrder = remote.displayOrder
    ..functionalSection = remote.functionalSection
    ..componentGroup = remote.componentGroup
    ..subsystem = remote.subsystem
    ..targetRef = remote.targetRef
    ..targetRefs = List<String>.from(remote.targetRefs)
    ..procedureRefs = List<String>.from(remote.procedureRefs)
    ..safetyConfirmations = List<String>.from(remote.safetyConfirmations)
    ..tags = List<String>.from(remote.tags)
    ..operationalStatePreconditions = List<String>.from(
      remote.operationalStatePreconditions,
    )
    ..responsesJson = remote.responsesJson
    ..actionsJson = remote.actionsJson
    ..draftNote = remote.draftNote
    ..submissionNote = remote.submissionNote
    ..acceptanceNote = remote.acceptanceNote
    ..reopenReason = remote.reopenReason
    ..notApplicableReason = remote.notApplicableReason
    ..pendingIssue = remote.pendingIssue
    ..requiresFollowUp = remote.requiresFollowUp
    ..addedByUid = remote.addedByUid
    ..addedByName = remote.addedByName
    ..addedAt = remote.addedAt
    ..addReason = remote.addReason
    ..createdByUid = remote.createdByUid
    ..createdByName = remote.createdByName
    ..createdAt = remote.createdAt
    ..updatedByUid = remote.updatedByUid
    ..updatedByName = remote.updatedByName
    ..updatedAt = remote.updatedAt
    ..submittedByUid = remote.submittedByUid
    ..submittedByName = remote.submittedByName
    ..submittedAt = remote.submittedAt
    ..acceptedByUid = remote.acceptedByUid
    ..acceptedByName = remote.acceptedByName
    ..acceptedAt = remote.acceptedAt
    ..reopenedByUid = remote.reopenedByUid
    ..reopenedByName = remote.reopenedByName
    ..reopenedAt = remote.reopenedAt
    ..notApplicableByUid = remote.notApplicableByUid
    ..notApplicableByName = remote.notApplicableByName
    ..notApplicableAt = remote.notApplicableAt
    ..isDeleted = remote.isDeleted
    ..deletedAt = remote.deletedAt
    ..deletedByUid = remote.deletedByUid
    ..deletedByName = remote.deletedByName
    ..deleteReason = remote.deleteReason
    ..metadataJson = remote.metadataJson;
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedJobModuleResult {
  final List<JobModuleInstance> records;
  final DocumentSnapshot? lastDoc;

  PaginatedJobModuleResult({required this.records, this.lastDoc});
}

class JobModuleQueryKey {
  final String? jobExecutionFirestoreId;
  final int? jobExecutionLocalId;
  final JobModuleDiscipline? discipline;
  final int? limit;

  const JobModuleQueryKey({
    this.jobExecutionFirestoreId,
    this.jobExecutionLocalId,
    this.discipline,
    this.limit,
  });

  @override
  bool operator ==(Object other) {
    return other is JobModuleQueryKey &&
        other.jobExecutionFirestoreId == jobExecutionFirestoreId &&
        other.jobExecutionLocalId == jobExecutionLocalId &&
        other.discipline == discipline &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    jobExecutionFirestoreId,
    jobExecutionLocalId,
    discipline,
    limit,
  );
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class JobModuleRepository {
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
  });

  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  });

  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  });

  Future<void> softDeleteModule(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  });

  Future<void> reopenModule(
    dynamic id, {
    required AppUser actor,
    String? reopenReason,
    AuditContext? auditContext,
  });

  Future<void> applyWorkflowModuleReopenProjection(
    String firestoreId, {
    required AppUser actor,
    required String reason,
    required DateTime appliedAt,
  });


  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  });

  Future<void> acceptModule(
    dynamic id, {
    required AppUser actor,
    String? acceptanceNote,
    AuditContext? auditContext,
  });

  Future<JobModuleInstance?> getModuleByFirestoreId(String firestoreId);
  Future<List<JobModuleInstance>> getUnsyncedModules();
  Future<void> markModulesSynced(List<int> ids);
  Future<void> markModulesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> insertModuleFromRemote(JobModuleInstance remote);
  Future<void> updateModuleFromRemote(JobModuleInstance remote);

  /// Forcefully rebases a dirty local module from the remote canonical copy.
  /// Used only by sync repair after Firestore rules reject an impossible
  /// terminal-state push and the local snapshot has been preserved in audit.
  Future<void> forceRebaseModuleFromRemote(
    JobModuleInstance remote, {
    String? reason,
  });

  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobModuleInstance remote,
  );

  Future<PaginatedJobModuleResult> getUpdatedModules({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  });

  Future<List<JobModuleInstance>> getModulesByFirestoreIds(List<String> ids);
  Future<void> batchUpsertModules(List<JobModuleInstance> records);

  /// Applies one server-visible lifecycle replay step as a remote field-scoped merge.
  ///
  /// This is intentionally narrower than a general map-write escape hatch: it is
  /// used only by the push service when a local-first job-module lifecycle has
  /// collapsed multiple offline transitions into one dirty final snapshot. The
  /// caller must send only the fields allowed for that single Firestore rules
  /// transition. Local repositories do not support this remote push primitive.
  Future<void> applyRemoteLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  );
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class IsarJobModuleRepository implements JobModuleRepository {
  final AuditRepository _auditRepo;

  IsarJobModuleRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  @override
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
  }) async {
    final isCreate = module.id == Isar.autoIncrement;
    if (actor == null) {
      throw StateError('Actor is required when saving planned-job modules.');
    }
    if (isCreate) {
      _requireCanAddModuleDuringExecution(actor);
      _requireRuntimeModuleAddControl(actor, module);
    } else {
      _requireCanSaveModuleWork(actor, module);
    }

    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      JobModuleInstance? existing;
      if (!isCreate && module.id != Isar.autoIncrement) {
        existing = await isar.jobModuleInstances.get(module.id);
        beforeSnapshot = existing?.toAuditMap();
      }

      _normaliseModuleForUserSave(
        module,
        markUnsynced: true,
        auditContext: auditContext,
        incrementVersion: existing != null,
      );

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null && afterSnapshot != null && entityId != null) {
      final action =
          beforeSnapshot == null ? AuditAction.create : AuditAction.update;
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: action,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ??
                  (action == AuditAction.create
                      ? 'Added planned-maintenance module'
                      : 'Updated planned-maintenance module'),
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) async {
    final resolution = await _loadResolvedModulesForJob(
      jobExecutionFirestoreId: jobExecutionFirestoreId,
      jobExecutionLocalId: jobExecutionLocalId,
      discipline: discipline,
    );

    _reportForeignParentCollisions(
      resolution.ignoredForeignParentCollisions,
      jobExecutionFirestoreId,
    );
    _assertNoIdentityAmbiguity(resolution, jobExecutionFirestoreId);
    final modules = resolution.modules;
    _sortModules(modules);
    if (limit != null && modules.length > limit) {
      return modules.take(limit).toList();
    }
    return modules;
  }

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);

    if (cleanedFirestoreId == null) {
      return _localJobQuery(
        jobExecutionLocalId: jobExecutionLocalId,
        discipline: discipline,
      ).watch(fireImmediately: true).map((localModules) {
        final resolution = PlannedJobModuleSetResolver.resolve(
          executionFirestoreId: null,
          executionLocalId: jobExecutionLocalId ?? -1,
          firestoreLinkedModules: const <JobModuleInstance>[],
          localLinkedModules: localModules,
        );
        _reportForeignParentCollisions(
          resolution.ignoredForeignParentCollisions,
          null,
        );
        _assertNoIdentityAmbiguity(resolution, null);
        final modules = resolution.modules;
        _sortModules(modules);
        return limit != null && modules.length > limit
            ? modules.take(limit).toList()
            : modules;
      });
    }

    final remoteStream = _remoteJobQuery(
      jobExecutionFirestoreId: cleanedFirestoreId,
      discipline: discipline,
    ).watch(fireImmediately: true);
    final localStream = _localJobQuery(
      jobExecutionLocalId: jobExecutionLocalId,
      discipline: discipline,
    ).watch(fireImmediately: true);

    return _combineResolvedModuleStreams(
      remoteStream: remoteStream,
      localStream: localStream,
      jobExecutionFirestoreId: cleanedFirestoreId,
      jobExecutionLocalId: jobExecutionLocalId,
      limit: limit,
    );
  }

  Future<PlannedJobModuleSetResolution> _loadResolvedModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    final localId = jobExecutionLocalId ?? -1;

    if (cleanedFirestoreId == null) {
      final localModules =
          jobExecutionLocalId == null
              ? <JobModuleInstance>[]
              : await _localJobQuery(
                jobExecutionLocalId: jobExecutionLocalId,
                discipline: discipline,
              ).findAll();
      return PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: null,
        executionLocalId: localId,
        firestoreLinkedModules: const <JobModuleInstance>[],
        localLinkedModules: localModules,
      );
    }

    final remoteModules =
        await _remoteJobQuery(
          jobExecutionFirestoreId: cleanedFirestoreId,
          discipline: discipline,
        ).findAll();
    final localModules =
        jobExecutionLocalId == null
            ? <JobModuleInstance>[]
            : await _localJobQuery(
              jobExecutionLocalId: jobExecutionLocalId,
              discipline: discipline,
            ).findAll();

    return PlannedJobModuleSetResolver.resolve(
      executionFirestoreId: cleanedFirestoreId,
      executionLocalId: localId,
      firestoreLinkedModules: remoteModules,
      localLinkedModules: localModules,
    );
  }

  Stream<List<JobModuleInstance>> _combineResolvedModuleStreams({
    required Stream<List<JobModuleInstance>> remoteStream,
    required Stream<List<JobModuleInstance>> localStream,
    required String jobExecutionFirestoreId,
    required int? jobExecutionLocalId,
    int? limit,
  }) {
    late StreamController<List<JobModuleInstance>> controller;
    StreamSubscription<List<JobModuleInstance>>? remoteSubscription;
    StreamSubscription<List<JobModuleInstance>>? localSubscription;
    List<JobModuleInstance>? remoteLatest;
    List<JobModuleInstance>? localLatest;

    void emitIfReady() {
      final remote = remoteLatest;
      final local = localLatest;
      if (remote == null || local == null || controller.isClosed) return;

      final resolution = PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: jobExecutionFirestoreId,
        executionLocalId: jobExecutionLocalId ?? -1,
        firestoreLinkedModules: remote,
        localLinkedModules: local,
      );
      _reportForeignParentCollisions(
        resolution.ignoredForeignParentCollisions,
        jobExecutionFirestoreId,
      );
      try {
        _assertNoIdentityAmbiguity(resolution, jobExecutionFirestoreId);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
        return;
      }
      final modules = resolution.modules;
      _sortModules(modules);
      controller.add(
        limit != null && modules.length > limit
            ? modules.take(limit).toList()
            : modules,
      );
    }

    controller = StreamController<List<JobModuleInstance>>(
      onListen: () {
        remoteSubscription = remoteStream.listen((value) {
          remoteLatest = value;
          emitIfReady();
        }, onError: controller.addError);
        localSubscription = localStream.listen((value) {
          localLatest = value;
          emitIfReady();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await remoteSubscription?.cancel();
        await localSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
  _remoteJobQuery({
    required String jobExecutionFirestoreId,
    JobModuleDiscipline? discipline,
  }) {
    var query = isar.jobModuleInstances
        .filter()
        .jobExecutionFirestoreIdEqualTo(jobExecutionFirestoreId)
        .and()
        .isDeletedEqualTo(false);
    if (discipline != null) {
      query = query.and().disciplineEqualTo(discipline);
    }
    return query;
  }

  QueryBuilder<JobModuleInstance, JobModuleInstance, QAfterFilterCondition>
  _localJobQuery({
    required int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
  }) {
    var query =
        jobExecutionLocalId == null
            ? isar.jobModuleInstances
                .filter()
                .firestoreIdEqualTo('__no_matching_job_module__')
                .and()
                .isDeletedEqualTo(false)
            : isar.jobModuleInstances
                .filter()
                .jobExecutionLocalIdEqualTo(jobExecutionLocalId)
                .and()
                .isDeletedEqualTo(false);
    if (discipline != null) {
      query = query.and().disciplineEqualTo(discipline);
    }
    return query;
  }

  void _reportForeignParentCollisions(
    Iterable<JobModuleInstance> collisions,
    String? currentExecutionFirestoreId,
  ) {
    for (final module in collisions) {
      debugPrint(
        '⚠️ Ignored foreign-parent module linked by a non-authoritative local id: '
        'module=${module.moduleTitle}, moduleFirestoreId=${module.firestoreId}, '
        'actualExecution=${module.jobExecutionFirestoreId}, '
        'currentExecution=$currentExecutionFirestoreId, '
        'localExecutionId=${module.jobExecutionLocalId}',
      );
    }
  }

  void _assertNoIdentityAmbiguity(
    PlannedJobModuleSetResolution resolution,
    String? currentExecutionFirestoreId,
  ) {
    final unresolved = resolution.unresolvedLocalParentModules;
    if (unresolved.isNotEmpty) {
      final ids = unresolved
          .map((module) => module.firestoreId ?? 'local:${module.id}')
          .join(', ');
      throw StateError(
        'Planned-job module identity is unresolved for '
        '${unresolved.length} local module(s). The current execution has '
        'canonical Firestore id $currentExecutionFirestoreId, but these '
        'modules do not. Sync/reconciliation must repair the parent relation '
        'before work or closure can continue. Modules: $ids',
      );
    }

    final duplicates = resolution.duplicateCanonicalModules;
    if (duplicates.isNotEmpty) {
      final ids = duplicates
          .map(
            (module) =>
                '${module.firestoreId ?? 'local:${module.id}'}@isar:${module.id}',
          )
          .join(', ');
      throw StateError(
        'Planned-job module identity is ambiguous: distinct local rows claim '
        'the same canonical module Firestore id. Resolve the duplicate without '
        'discarding evidence before work or closure can continue. Rows: $ids',
      );
    }
  }

  static void _sortModules(List<JobModuleInstance> modules) {
    modules.sort((a, b) {
      final displayOrderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (displayOrderCompare != 0) return displayOrderCompare;

      final disciplineCompare = a.discipline.name.compareTo(b.discipline.name);
      if (disciplineCompare != 0) return disciplineCompare;

      return a.moduleTitle.compareTo(b.moduleTitle);
    });
  }

  @override
  Future<void> softDeleteModule(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final moduleId = id as int;
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final module = await isar.jobModuleInstances.get(moduleId);
      if (module == null || module.isDeleted) return;
      _requireCanModerateModule(actor, ModuleModerationAction.softDelete);

      beforeSnapshot = module.toAuditMap();
      final now = DateTime.now();

      module
        ..isDeleted = true
        ..deletedAt = now
        ..deletedByUid = actor.uid
        ..deletedByName = _cleanOptionalText(actor.name)
        ..deleteReason = auditContext?.reason?.name ?? auditContext?.reasonNotes
        ..updatedAt = now
        ..updatedByUid =
            _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
        ..updatedByName =
            _cleanOptionalText(auditContext?.performedByName) ??
            _cleanOptionalText(actor.name)
        ..version += 1
        ..isSynced = false;

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary:
                  auditContext.summary ?? 'Deleted planned-maintenance module',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  }) async {
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.update,
      auditSummary: 'Submitted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanSubmitModule(actor, module);
        _requireOpenForWork(module, 'submit this module');
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.submitted
          ..submittedByUid = actor.uid
          ..submittedByName = _cleanOptionalText(actor.name)
          ..submittedAt = now
          ..submissionNote = _cleanOptionalText(submissionNote)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
      },
    );
  }

  @override
  Future<void> reopenModule(
    dynamic id, {
    required AppUser actor,
    String? reopenReason,
    AuditContext? auditContext,
  }) async {
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.reopen,
      auditSummary: 'Reopened planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.reopen);
        _requireReopenable(module);
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.reopened
          ..reopenedByUid = actor.uid
          ..reopenedByName = _cleanOptionalText(actor.name)
          ..reopenedAt = now
          ..reopenReason = _cleanOptionalText(reopenReason)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
      },
    );
  }

  @override
  Future<void> applyWorkflowModuleReopenProjection(
    String firestoreId, {
    required AppUser actor,
    required String reason,
    required DateTime appliedAt,
  }) async {
    final module = await isar.jobModuleInstances
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
    if (module == null) return;
    await isar.writeTxn(() async {
      module
        ..status = JobModuleStatus.reopened
        ..isDeleted = false
        ..reopenedByUid = actor.uid
        ..reopenedByName = _cleanOptionalText(actor.name)
        ..reopenedAt = appliedAt
        ..reopenReason = _cleanOptionalText(reason)
        ..updatedByUid = actor.uid
        ..updatedByName = _cleanOptionalText(actor.name)
        ..updatedAt = appliedAt
        ..version += 1
        ..isSynced = true;
      await isar.jobModuleInstances.put(module);
    });
  }

  @override
  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  }) async {
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.update,
      auditSummary: 'Marked planned-maintenance module not applicable',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(
          actor,
          ModuleModerationAction.markNotApplicable,
        );
        _requireOpenForWork(module, 'mark this module not applicable');
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.notApplicable
          ..notApplicableByUid = actor.uid
          ..notApplicableByName = _cleanOptionalText(actor.name)
          ..notApplicableAt = now
          ..notApplicableReason = _cleanRequiredText(reason, 'Not applicable')
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
      },
    );
  }

  @override
  Future<void> acceptModule(
    dynamic id, {
    required AppUser actor,
    String? acceptanceNote,
    AuditContext? auditContext,
  }) async {
    // Accept is a per-module review decision. It does not complete the parent
    // JobExecution and it does not evaluate required-for-closure job gating.
    // Accepted modules are locked for normal users and may only be reopened by
    // supervisor/Admin/SI with a reason.
    await _transitionLocalModule(
      id as int,
      auditAction: AuditAction.update,
      auditSummary: 'Accepted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.accept);
        _requireSubmitted(module, 'accept this module');
      },
      mutate: (module, now) {
        module
          ..status = JobModuleStatus.accepted
          ..acceptedByUid = actor.uid
          ..acceptedByName = _cleanOptionalText(actor.name)
          ..acceptedAt = now
          ..acceptanceNote = _cleanOptionalText(acceptanceNote)
          ..updatedByUid =
              _cleanOptionalText(auditContext?.performedByUid) ?? actor.uid
          ..updatedByName =
              _cleanOptionalText(auditContext?.performedByName) ??
              _cleanOptionalText(actor.name);
      },
    );
  }

  Future<void> _transitionLocalModule(
    int id, {
    required AuditAction auditAction,
    required String auditSummary,
    required void Function(JobModuleInstance module, DateTime now) mutate,
    void Function(JobModuleInstance module)? validate,
    AuditContext? auditContext,
  }) async {
    Map<String, dynamic>? beforeSnapshot;
    Map<String, dynamic>? afterSnapshot;
    String? entityId;

    await isar.writeTxn(() async {
      final module = await isar.jobModuleInstances.get(id);
      if (module == null || module.isDeleted) return;

      validate?.call(module);
      beforeSnapshot = module.toAuditMap();
      final now = DateTime.now();
      mutate(module, now);
      module
        ..updatedAt = now
        ..version += 1
        ..isSynced = false;

      await isar.jobModuleInstances.put(module);
      afterSnapshot = module.toAuditMap();
      entityId = module.firestoreId ?? module.id.toString();
    });

    if (auditContext != null &&
        beforeSnapshot != null &&
        afterSnapshot != null &&
        entityId != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: entityId!,
            action: auditAction,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
              summary: auditContext.summary ?? auditSummary,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<JobModuleInstance?> getModuleByFirestoreId(String firestoreId) async {
    return isar.jobModuleInstances
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async {
    return isar.jobModuleInstances.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markModulesSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    await isar.writeTxn(() async {
      final modules = await isar.jobModuleInstances.getAll(ids);
      for (final module in modules.whereType<JobModuleInstance>()) {
        module.isSynced = true;
        await isar.jobModuleInstances.put(module);
      }
    });
  }

  @override
  Future<void> markModulesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final modules = await isar.jobModuleInstances.getAll(byId.keys.toList());
      for (final module in modules.whereType<JobModuleInstance>()) {
        final pushed = byId[module.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: module.version,
          currentUpdatedAt: module.updatedAt,
        )) {
          continue;
        }
        module.isSynced = true;
        await isar.jobModuleInstances.put(module);
      }
    });
  }

  @override
  Future<void> insertModuleFromRemote(JobModuleInstance remote) async {
    remote
      ..jobExecutionLocalId = null
      ..isSynced = true;
    await isar.writeTxn(() => isar.jobModuleInstances.put(remote));
  }

  @override
  Future<void> updateModuleFromRemote(JobModuleInstance remote) async {
    if (remote.firestoreId == null) return;

    await isar.writeTxn(() async {
      final local =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      if (remote.isDeleted) {
        final remoteDeleteTime = remote.deletedAt ?? remote.updatedAt;
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced module against remote tombstone in updateModuleFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }

        if (!local.isDeleted) {
          _copyRemoteModuleIntoLocal(local, remote);
          await isar.jobModuleInstances.put(local);
        }
        return;
      }

      final isLocalUnsynced = !local.isSynced;
      final isRemoteNewer = _isRemoteNewerByPolicy(local, remote);
      final isLocalNewer = local.updatedAt.isAfter(remote.updatedAt);

      if (isLocalUnsynced && !isRemoteNewer) return;
      if (!isLocalUnsynced && isLocalNewer) return;

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
    });
  }

  @override
  Future<void> forceRebaseModuleFromRemote(
    JobModuleInstance remote, {
    String? reason,
  }) async {
    if (remote.firestoreId == null) return;

    await isar.writeTxn(() async {
      final local =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(remote.firestoreId!)
              .findFirst();

      if (local == null) return;

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
    });

    if (reason != null && reason.trim().isNotEmpty) {
      debugPrint(
        '🛡️ Rebased local job module from remote canonical state: '
        'firestoreId=${remote.firestoreId}, reason=$reason',
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobModuleInstance remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local =
          await isar.jobModuleInstances
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
          '🛡️ Preserved fresher unsynced module against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      _copyRemoteModuleIntoLocal(local, remote);
      await isar.jobModuleInstances.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<PaginatedJobModuleResult> getUpdatedModules({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedJobModuleResult(records: [], lastDoc: null);
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <JobModuleInstance>[];
    for (final firestoreId in ids) {
      final module =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();
      if (module != null) results.add(module);
    }
    return results;
  }

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    if (records.isEmpty) return;
    await isar.writeTxn(() async {
      for (final record in records) {
        if (_cleanOptionalText(record.jobExecutionFirestoreId) != null) {
          record.jobExecutionLocalId = null;
        }
        await isar.jobModuleInstances.put(record);
      }
    });
  }

  @override
  Future<void> applyRemoteLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) {
    throw UnsupportedError(
      'applyRemoteLifecycleReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar job-module repository.',
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

class _RemoteModuleTransitionResult {
  final JobModuleInstance before;

  const _RemoteModuleTransitionResult({required this.before});
}

class FirestoreJobModuleRepository implements JobModuleRepository {
  final AuditRepository _auditRepo;
  final RuntimeJobModulePopulationService _populationService;

  FirestoreJobModuleRepository({
    AuditRepository? auditRepository,
    RuntimeJobModulePopulationService? populationService,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _populationService =
           populationService ?? RuntimeJobModulePopulationService();

  final _modules = FirebaseFirestore.instance.collection('job_modules');

  @override
  Future<void> saveModule(
    JobModuleInstance module, {
    AppUser? actor,
    AuditContext? auditContext,
  }) async {
    final existing =
        module.firestoreId == null
            ? null
            : await _modules.doc(module.firestoreId).get();
    final before =
        existing != null && existing.exists && existing.data() != null
            ? JobModuleInstance.fromMap(existing.data()!, existing.id)
            : null;

    if (actor == null) {
      throw StateError('Actor is required when saving planned-job modules.');
    }
    if (before == null) {
      _requireCanAddModuleDuringExecution(actor);
      _requireRuntimeModuleAddControl(actor, module);
    } else {
      _requireCanSaveModuleWork(actor, module);
    }

    _normaliseModuleForUserSave(
      module,
      markUnsynced: false,
      auditContext: auditContext,
      preserveCreatedAt: true,
      incrementVersion: before != null,
    );

    if (before == null) {
      final accepted = await _populationService.acceptModule(module);
      _copyRemoteModuleIntoLocal(module, accepted.module);
    } else {
      await _modules
          .doc(module.firestoreId)
          .set(module.toMap(), SetOptions(merge: true));
    }
    module.isSynced = true;

    if (auditContext != null && before != null) {
      // First remote acceptance already writes the authoritative immutable
      // create audit in the same server transaction as the child and parent
      // population-fence update. Emit a client audit only for later ordinary
      // lifecycle/work updates, never a duplicate create record.
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'planned_job_module',
            entityId: module.firestoreId!,
            action: AuditAction.update,
            context: auditContext.copyWith(
              before: before.toAuditMap(),
              after: module.toAuditMap(),
              summary:
                  auditContext.summary ?? 'Updated planned-maintenance module',
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) async {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) return [];

    Query<Map<String, dynamic>> query = _modules
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('displayOrder')
        .orderBy('moduleTitle');

    if (discipline != null) {
      query = query.where('discipline', isEqualTo: discipline.name);
    }

    if (limit != null) query = query.limit(limit);

    final snap = await query.get();
    return snap.docs
        .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) {
    final cleanedFirestoreId = _cleanOptionalText(jobExecutionFirestoreId);
    if (cleanedFirestoreId == null) {
      return Stream<List<JobModuleInstance>>.value(const []);
    }

    Query<Map<String, dynamic>> query = _modules
        .where('jobExecutionFirestoreId', isEqualTo: cleanedFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('displayOrder')
        .orderBy('moduleTitle');

    if (discipline != null) {
      query = query.where('discipline', isEqualTo: discipline.name);
    }

    if (limit != null) query = query.limit(limit);

    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> softDeleteModule(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final docId = id as String;
    _requireCanModerateModule(actor, ModuleModerationAction.softDelete);

    final doc = await _modules.doc(docId).get();
    if (!doc.exists || doc.data() == null) return;
    final before = JobModuleInstance.fromMap(doc.data()!, doc.id);
    if (before.isDeleted) return;

    final now = DateTime.now();
    final tombstone =
        JobModuleInstance.fromMap(before.toMap(), doc.id)
          ..isDeleted = true
          ..deletedAt = now
          ..deletedByUid = actor.uid
          ..deletedByName = _cleanOptionalText(actor.name)
          ..deleteReason =
              auditContext?.reason?.name ?? auditContext?.reasonNotes
          ..updatedAt = now
          ..updatedByUid = actor.uid
          ..updatedByName = _cleanOptionalText(actor.name)
          ..version = before.version + 1;

    final after = await _populationService.softDeleteModule(tombstone);
    _copyRemoteModuleIntoLocal(tombstone, after.module);

    // The server callable writes the only authoritative delete audit in the
    // same transaction as the tombstone and parent population increment.
    // Do not create a second client-side audit for the same mutation.
  }

  @override
  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Submitted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanSubmitModule(actor, module);
        _requireOpenForWork(module, 'submit this module');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.submitted.name,
            'isOpenForWork': false,
            'submittedByUid': actor.uid,
            'submittedByName': _cleanOptionalText(actor.name),
            'submittedAt': now.toIso8601String(),
            'submissionNote': _cleanOptionalText(submissionNote),
          },
    );
  }

  @override
  Future<void> reopenModule(
    dynamic id, {
    required AppUser actor,
    String? reopenReason,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.reopen,
      auditSummary: 'Reopened planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.reopen);
        _requireReopenable(module);
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.reopened.name,
            'isOpenForWork': true,
            'reopenedByUid': actor.uid,
            'reopenedByName': _cleanOptionalText(actor.name),
            'reopenedAt': now.toIso8601String(),
            'reopenReason': _cleanOptionalText(reopenReason),
          },
    );
  }

  @override
  Future<void> applyWorkflowModuleReopenProjection(
    String firestoreId, {
    required AppUser actor,
    required String reason,
    required DateTime appliedAt,
  }) async {
    // The workflow command has already committed the canonical Firestore
    // transition. Web views observe that document directly.
  }

  @override
  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  }) async {
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Marked planned-maintenance module not applicable',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(
          actor,
          ModuleModerationAction.markNotApplicable,
        );
        _requireOpenForWork(module, 'mark this module not applicable');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.notApplicable.name,
            'isOpenForWork': false,
            'notApplicableByUid': actor.uid,
            'notApplicableByName': _cleanOptionalText(actor.name),
            'notApplicableAt': now.toIso8601String(),
            'notApplicableReason': _cleanRequiredText(reason, 'Not applicable'),
          },
    );
  }

  @override
  Future<void> acceptModule(
    dynamic id, {
    required AppUser actor,
    String? acceptanceNote,
    AuditContext? auditContext,
  }) async {
    // Accept is a per-module review decision. It does not complete the parent
    // JobExecution and it does not evaluate required-for-closure job gating.
    // Accepted modules are locked for normal users and may only be reopened by
    // supervisor/Admin/SI with a reason.
    await _transitionRemoteModule(
      id as String,
      auditAction: AuditAction.update,
      auditSummary: 'Accepted planned-maintenance module',
      auditContext: auditContext,
      validate: (module) {
        _requireCanModerateModule(actor, ModuleModerationAction.accept);
        _requireSubmitted(module, 'accept this module');
      },
      buildUpdate:
          (now) => {
            'status': JobModuleStatus.accepted.name,
            'isOpenForWork': false,
            'acceptedByUid': actor.uid,
            'acceptedByName': _cleanOptionalText(actor.name),
            'acceptedAt': now.toIso8601String(),
            'acceptanceNote': _cleanOptionalText(acceptanceNote),
          },
    );
  }

  Future<void> _transitionRemoteModule(
    String docId, {
    required AuditAction auditAction,
    required String auditSummary,
    required Map<String, dynamic> Function(DateTime now) buildUpdate,
    void Function(JobModuleInstance module)? validate,
    AuditContext? auditContext,
  }) async {
    final docRef = _modules.doc(docId);

    final result = await FirebaseFirestore.instance
        .runTransaction<_RemoteModuleTransitionResult?>((transaction) async {
          final doc = await transaction.get(docRef);
          if (!doc.exists || doc.data() == null) return null;

          final before = JobModuleInstance.fromMap(doc.data()!, doc.id);
          validate?.call(before);

          final now = DateTime.now();
          final updateMap = <String, dynamic>{
            ...buildUpdate(now),
            'updatedAt': now.toIso8601String(),
            'version': FieldValue.increment(1),
          };

          if (auditContext != null) {
            updateMap['updatedByUid'] = auditContext.performedByUid;
            updateMap['updatedByName'] = auditContext.performedByName;
          }

          transaction.update(docRef, updateMap);

          return _RemoteModuleTransitionResult(before: before);
        });

    if (result == null || auditContext == null) return;

    final afterDoc = await docRef.get();
    final after =
        afterDoc.data() != null
            ? JobModuleInstance.fromMap(afterDoc.data()!, afterDoc.id)
            : null;

    final auditRepo = _auditRepo;
    try {
      await auditRepo.log(
        AuditEvent.fromContext(
          entityType: 'planned_job_module',
          entityId: docId,
          action: auditAction,
          context: auditContext.copyWith(
            before: result.before.toAuditMap(),
            after: after?.toAuditMap(),
            summary: auditContext.summary ?? auditSummary,
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        '⚠️ Remote planned-job module transition audit failed for $docId: $error',
      );
    }
  }

  @override
  Future<JobModuleInstance?> getModuleByFirestoreId(String firestoreId) async {
    final doc = await _modules.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;
    return JobModuleInstance.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async => [];

  @override
  Future<void> markModulesSynced(List<int> ids) async {}

  @override
  Future<void> markModulesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertModuleFromRemote(JobModuleInstance remote) async {}

  @override
  Future<void> updateModuleFromRemote(JobModuleInstance remote) async {}

  @override
  Future<void> forceRebaseModuleFromRemote(
    JobModuleInstance remote, {
    String? reason,
  }) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(
    JobModuleInstance remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<PaginatedJobModuleResult> getUpdatedModules({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The job-module pull has no server upper bound.',
        reasonCode: 'job-module-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _modules,
      afterInclusive: since,
      throughInclusive: through,
    );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.limit(limit).get();
    return PaginatedJobModuleResult(
      records:
          snap.docs
              .map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final results = <JobModuleInstance>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _modules.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => JobModuleInstance.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    if (records.isEmpty) return;

    final recordsWithIds = records
        .where((record) => _cleanOptionalText(record.firestoreId) != null)
        .toList(growable: false);
    if (recordsWithIds.isEmpty) return;

    final remote = await getModulesByFirestoreIds(
      recordsWithIds.map((record) => record.firestoreId!).toList(),
    );
    final remoteById = <String, JobModuleInstance>{
      for (final record in remote)
        if (record.firestoreId != null) record.firestoreId!: record,
    };

    final directUpdates = <JobModuleInstance>[];
    for (final record in recordsWithIds) {
      final firestoreId = record.firestoreId!;
      final existing = remoteById[firestoreId];

      if (record.isDeleted) {
        // Deleting a never-synchronized local module is already remotely
        // satisfied: there is no child document to remove from the population.
        if (existing == null || existing.isDeleted) continue;
        await _populationService.softDeleteModule(record);
        continue;
      }

      if (existing == null) {
        await _populationService.acceptModule(record);
        continue;
      }

      // A first acceptance may have committed even when the client lost the
      // callable response. If the canonical client payload already matches,
      // remote acceptance is satisfied and the sync layer may safely mark the
      // unchanged local snapshot synchronized without issuing a stale
      // same-version direct update.
      if (jobModuleClientSnapshotsEquivalentForSync(record, existing)) {
        continue;
      }

      directUpdates.add(record);
    }

    final firestore = FirebaseFirestore.instance;
    for (var i = 0; i < directUpdates.length; i += 500) {
      final chunk = directUpdates.sublist(
        i,
        i + 500 > directUpdates.length ? directUpdates.length : i + 500,
      );
      final batch = firestore.batch();
      for (final record in chunk) {
        batch.set(
          _modules.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  @override
  Future<void> applyRemoteLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteLifecycleReplayStepForSync requires a non-empty firestoreId',
      );
    }

    // Field-scoped merge: the caller provides only the keys for one lifecycle
    // rule branch. This avoids pushing a final dirty snapshot that collapses
    // submit+accept into a single Firestore update.
    await _modules.doc(id).set(stepData, SetOptions(merge: true));
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final isarJobModuleRepoProvider = Provider<IsarJobModuleRepository>((ref) {
  return IsarJobModuleRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final firestoreJobModuleRepoProvider = Provider<FirestoreJobModuleRepository>((
  ref,
) {
  return FirestoreJobModuleRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  );
});

final jobModuleRepositoryProvider = Provider<JobModuleRepository>((ref) {
  return kIsWeb
      ? ref.watch(firestoreJobModuleRepoProvider)
      : ref.watch(isarJobModuleRepoProvider);
});

final jobModulesProvider =
    StreamProvider.family<List<JobModuleInstance>, JobModuleQueryKey>((
      ref,
      key,
    ) {
      return ref
          .watch(jobModuleRepositoryProvider)
          .watchModulesForJob(
            jobExecutionFirestoreId: key.jobExecutionFirestoreId,
            jobExecutionLocalId: key.jobExecutionLocalId,
            discipline: key.discipline,
            limit: key.limit,
          );
    });
