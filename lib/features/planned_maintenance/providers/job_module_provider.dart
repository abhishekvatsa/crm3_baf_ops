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

part 'job_module_provider.local.dart';
part 'job_module_provider.remote.dart';

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

void _requireCanSaveModuleWork(AppUser actor, JobModuleInstance module) {
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

  /// Adopts an audited terminal-state repair only while the local module still
  /// matches the row that was inspected before the network operation.
  Future<bool> applyModuleServerReadbackIfUnchanged(
    JobModuleInstance remote, {
    required SyncPushSnapshot expectedLocal,
    required bool expectedLocalSynced,
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
