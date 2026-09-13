part of 'job_module_provider.dart';

/// Complete native projection, deliberately not the normalized Firestore map.
/// The schema coverage test requires every persisted property to remain here.
Map<String, dynamic> jobModuleLocalSnapshot(JobModuleInstance module) => {
  'id': module.id,
  'firestoreId': module.firestoreId,
  'isSynced': module.isSynced,
  'version': module.version,
  'jobExecutionFirestoreId': module.jobExecutionFirestoreId,
  'jobExecutionLocalId': module.jobExecutionLocalId,
  'laneKey': module.laneKey,
  'laneActivationGeneration': module.laneActivationGeneration,
  'workflowLaneFirestoreId': module.workflowLaneFirestoreId,
  'templateFirestoreId': module.templateFirestoreId,
  'templateName': module.templateName,
  'templatePackageId': module.templatePackageId,
  'templateVersionId': module.templateVersionId,
  'templateModuleId': module.templateModuleId,
  'moduleCode': module.moduleCode,
  'moduleSnapshotJson': module.moduleSnapshotJson,
  'fieldDefinitionsJson': module.fieldDefinitionsJson,
  'assetType': module.assetType.name,
  'assetNumber': module.assetNumber,
  'chargeNoAtEvent': module.chargeNoAtEvent,
  'pairedEquipmentJson': module.pairedEquipmentJson,
  'moduleTitle': module.moduleTitle,
  'moduleDescription': module.moduleDescription,
  'status': module.status.name,
  'useMode': module.useMode.name,
  'discipline': module.discipline.name,
  'safetyClass': module.safetyClass.name,
  'isRequired': module.isRequired,
  'requiredForClosure': module.requiredForClosure,
  'addedDuringExecution': module.addedDuringExecution,
  'displayOrder': module.displayOrder,
  'functionalSection': module.functionalSection,
  'componentGroup': module.componentGroup,
  'subsystem': module.subsystem,
  'targetRef': module.targetRef,
  'targetRefs': module.targetRefs.toList(),
  'procedureRefs': module.procedureRefs.toList(),
  'safetyConfirmations': module.safetyConfirmations.toList(),
  'tags': module.tags.toList(),
  'operationalStatePreconditions': module.operationalStatePreconditions
      .toList(),
  'responsesJson': module.responsesJson,
  'actionsJson': module.actionsJson,
  'draftNote': module.draftNote,
  'submissionNote': module.submissionNote,
  'acceptanceNote': module.acceptanceNote,
  'reopenReason': module.reopenReason,
  'notApplicableReason': module.notApplicableReason,
  'pendingIssue': module.pendingIssue,
  'requiresFollowUp': module.requiresFollowUp,
  'addedByUid': module.addedByUid,
  'addedByName': module.addedByName,
  'addedAt': module.addedAt?.toUtc().toIso8601String(),
  'addReason': module.addReason,
  'createdByUid': module.createdByUid,
  'createdByName': module.createdByName,
  'createdAt': module.createdAt.toUtc().toIso8601String(),
  'updatedByUid': module.updatedByUid,
  'updatedByName': module.updatedByName,
  'updatedAt': module.updatedAt.toUtc().toIso8601String(),
  'submittedByUid': module.submittedByUid,
  'submittedByName': module.submittedByName,
  'submittedAt': module.submittedAt?.toUtc().toIso8601String(),
  'acceptedByUid': module.acceptedByUid,
  'acceptedByName': module.acceptedByName,
  'acceptedAt': module.acceptedAt?.toUtc().toIso8601String(),
  'reopenedByUid': module.reopenedByUid,
  'reopenedByName': module.reopenedByName,
  'reopenedAt': module.reopenedAt?.toUtc().toIso8601String(),
  'notApplicableByUid': module.notApplicableByUid,
  'notApplicableByName': module.notApplicableByName,
  'notApplicableAt': module.notApplicableAt?.toUtc().toIso8601String(),
  'isDeleted': module.isDeleted,
  'deletedAt': module.deletedAt?.toUtc().toIso8601String(),
  'deletedByUid': module.deletedByUid,
  'deletedByName': module.deletedByName,
  'deleteReason': module.deleteReason,
  'metadataJson': module.metadataJson,
};

/// Preserve native fields when opening an editor; a Firestore round trip can
/// derive lane IDs or normalize immutable metadata before the user edits it.
JobModuleInstance copyJobModuleForEditing(JobModuleInstance source) =>
    JobModuleInstance()
      ..id = source.id
      ..firestoreId = source.firestoreId
      ..isSynced = source.isSynced
      ..version = source.version
      ..jobExecutionFirestoreId = source.jobExecutionFirestoreId
      ..jobExecutionLocalId = source.jobExecutionLocalId
      ..laneKey = source.laneKey
      ..laneActivationGeneration = source.laneActivationGeneration
      ..workflowLaneFirestoreId = source.workflowLaneFirestoreId
      ..templateFirestoreId = source.templateFirestoreId
      ..templateName = source.templateName
      ..templatePackageId = source.templatePackageId
      ..templateVersionId = source.templateVersionId
      ..templateModuleId = source.templateModuleId
      ..moduleCode = source.moduleCode
      ..moduleSnapshotJson = source.moduleSnapshotJson
      ..fieldDefinitionsJson = source.fieldDefinitionsJson
      ..assetType = source.assetType
      ..assetNumber = source.assetNumber
      ..chargeNoAtEvent = source.chargeNoAtEvent
      ..pairedEquipmentJson = source.pairedEquipmentJson
      ..moduleTitle = source.moduleTitle
      ..moduleDescription = source.moduleDescription
      ..status = source.status
      ..useMode = source.useMode
      ..discipline = source.discipline
      ..safetyClass = source.safetyClass
      ..isRequired = source.isRequired
      ..requiredForClosure = source.requiredForClosure
      ..addedDuringExecution = source.addedDuringExecution
      ..displayOrder = source.displayOrder
      ..functionalSection = source.functionalSection
      ..componentGroup = source.componentGroup
      ..subsystem = source.subsystem
      ..targetRef = source.targetRef
      ..targetRefs = source.targetRefs.toList()
      ..procedureRefs = source.procedureRefs.toList()
      ..safetyConfirmations = source.safetyConfirmations.toList()
      ..tags = source.tags.toList()
      ..operationalStatePreconditions = source.operationalStatePreconditions
          .toList()
      ..responsesJson = source.responsesJson
      ..actionsJson = source.actionsJson
      ..draftNote = source.draftNote
      ..submissionNote = source.submissionNote
      ..acceptanceNote = source.acceptanceNote
      ..reopenReason = source.reopenReason
      ..notApplicableReason = source.notApplicableReason
      ..pendingIssue = source.pendingIssue
      ..requiresFollowUp = source.requiresFollowUp
      ..addedByUid = source.addedByUid
      ..addedByName = source.addedByName
      ..addedAt = source.addedAt
      ..addReason = source.addReason
      ..createdByUid = source.createdByUid
      ..createdByName = source.createdByName
      ..createdAt = source.createdAt
      ..updatedByUid = source.updatedByUid
      ..updatedByName = source.updatedByName
      ..updatedAt = source.updatedAt
      ..submittedByUid = source.submittedByUid
      ..submittedByName = source.submittedByName
      ..submittedAt = source.submittedAt
      ..acceptedByUid = source.acceptedByUid
      ..acceptedByName = source.acceptedByName
      ..acceptedAt = source.acceptedAt
      ..reopenedByUid = source.reopenedByUid
      ..reopenedByName = source.reopenedByName
      ..reopenedAt = source.reopenedAt
      ..notApplicableByUid = source.notApplicableByUid
      ..notApplicableByName = source.notApplicableByName
      ..notApplicableAt = source.notApplicableAt
      ..isDeleted = source.isDeleted
      ..deletedAt = source.deletedAt
      ..deletedByUid = source.deletedByUid
      ..deletedByName = source.deletedByName
      ..deleteReason = source.deleteReason
      ..metadataJson = source.metadataJson;

class JobModuleSaveConflict implements Exception {
  final String conflictId;
  final String reason;
  const JobModuleSaveConflict(this.conflictId, this.reason);
  @override
  String toString() =>
      'This module changed or is no longer open. Your draft '
      'was saved separately. Open Saved drafts to review it.';
}

class JobModuleSavedDraft {
  final String conflictId;
  final int moduleLocalId;
  final String actorUid;
  final DateTime savedAt;
  final String reason;
  final String evidenceJson;
  const JobModuleSavedDraft({
    required this.conflictId,
    required this.moduleLocalId,
    required this.actorUid,
    required this.savedAt,
    required this.reason,
    required this.evidenceJson,
  });

  Map<String, dynamic> get evidence =>
      Map<String, dynamic>.from(jsonDecode(evidenceJson) as Map);
}

class JobModuleDraftReview {
  final JobModuleSavedDraft saved;
  final JobModuleInstance current;
  final JobModuleSaveBaseline baseline;
  final String? blockingReason;
  JobModuleDraftReview(this.saved, this.current, {this.blockingReason})
    : baseline = JobModuleSaveBaseline.capture(current);

  JobModuleInstance recoveryCandidate() {
    final attempted = Map<String, dynamic>.from(
      saved.evidence['attempted'] as Map,
    );
    final candidate = copyJobModuleForEditing(current)
      ..responsesJson = attempted['responsesJson'] as String
      ..actionsJson = attempted['actionsJson'] as String
      ..draftNote = attempted['draftNote'] as String?
      ..pendingIssue = attempted['pendingIssue'] as String?
      ..requiresFollowUp = attempted['requiresFollowUp'] as bool
      ..status = JobModuleStatus.values.singleWhere(
        (status) => status.name == attempted['status'],
      );
    return candidate;
  }
}

const _moduleConflictType = 'planned_job_module_edit_conflict';
const _moduleConflictPartType = 'planned_job_module_edit_conflict_part';
const _moduleConflictResolvedType = 'planned_job_module_edit_conflict_resolved';
const _moduleEditableFields = {
  'responsesJson',
  'actionsJson',
  'draftNote',
  'pendingIssue',
  'requiresFollowUp',
  'status',
  'updatedByUid',
  'updatedByName',
  'updatedAt',
};

bool _sameModuleNonWorkFields(
  JobModuleInstance current,
  JobModuleInstance candidate,
) {
  final before = jobModuleLocalSnapshot(current)
    ..removeWhere((key, _) => _moduleEditableFields.contains(key));
  final after = jobModuleLocalSnapshot(candidate)
    ..removeWhere((key, _) => _moduleEditableFields.contains(key));
  return jsonEncode(before) == jsonEncode(after);
}

Future<String?> _moduleParentSaveProblem(JobModuleInstance module) async {
  final canonicalId = _cleanOptionalText(module.jobExecutionFirestoreId);
  final parents = canonicalId != null
      ? await isar.jobExecutions
            .filter()
            .firestoreIdEqualTo(canonicalId)
            .findAll()
      : <JobExecution>[
          if (module.jobExecutionLocalId != null)
            ...[
              await isar.jobExecutions.get(module.jobExecutionLocalId!),
            ].whereType<JobExecution>(),
        ];
  if (parents.length != 1) return 'parent-missing-or-ambiguous';
  final parent = parents.single;
  if (canonicalId != null &&
      module.jobExecutionLocalId != null &&
      module.jobExecutionLocalId != parent.id) {
    return 'parent-link-needs-reconciliation';
  }
  if (canonicalId == null && _cleanOptionalText(parent.firestoreId) != null) {
    return 'parent-link-needs-reconciliation';
  }
  if (parent.isTerminal) return 'parent-closed';
  return null;
}

/// Called only inside the same write transaction that refused the business
/// mutation. Each immutable audit chunk fits the existing 20k Rules limit;
/// there is no pruning, synthetic origin or successful module-write claim.
Future<JobModuleSaveConflict> _retainModuleSaveConflict({
  required JobModuleInstance attempted,
  required JobModuleInstance? current,
  required JobModuleSaveBaseline? baseline,
  required AppUser actor,
  required String reason,
}) async {
  final conflictId = const Uuid().v4();
  final evidence = jsonEncode({
    'protocolVersion': 1,
    'actorUid': actor.uid,
    'moduleLocalId': attempted.id,
    'reviewed': baseline == null ? null : jsonDecode(baseline.preimageJson),
    'current': current == null ? null : jobModuleLocalSnapshot(current),
    'attempted': jobModuleLocalSnapshot(attempted),
    'reason': reason,
  });
  final bytes = utf8.encode(evidence);
  final encoded = base64Encode(bytes);
  final chunks = <String>[
    for (var offset = 0; offset < encoded.length; offset += 12000)
      encoded.substring(offset, (offset + 12000).clamp(0, encoded.length)),
  ];
  final digest = sha256.convert(bytes).toString();
  final events = <AuditEvent>[
    AuditEvent(
      entityType: _moduleConflictType,
      entityId: conflictId,
      action: AuditAction.create,
      performedByUid: actor.uid,
      performedByName: actor.name,
      summary: 'Module edit conflict: losing draft retained; module unchanged.',
      severity: AuditSeverity.medium,
      after: {
        'protocolVersion': 1,
        'moduleLocalId': attempted.id,
        'reason': reason,
        'evidenceSha256': digest,
        'chunkCount': chunks.length,
      },
    ),
    for (var index = 0; index < chunks.length; index++)
      AuditEvent(
        entityType: _moduleConflictPartType,
        entityId: conflictId,
        action: AuditAction.create,
        performedByUid: actor.uid,
        performedByName: actor.name,
        summary: 'Retained module draft evidence.',
        after: {
          'protocolVersion': 1,
          'chunkIndex': index,
          'evidenceSha256': digest,
          'bytesBase64': chunks[index],
        },
      ),
  ];
  await isar.auditEvents.putAll(events);
  return JobModuleSaveConflict(conflictId, reason);
}

/// Native saved-draft reader. Actor filtering occurs before payload decoding.
/// Remote audit permissions/availability are not used as a local recovery
/// dependency. No record is deleted when an operator reviews or reapplies it.
class JobModuleDraftRecovery {
  final IsarJobModuleRepository repository;
  JobModuleDraftRecovery({IsarJobModuleRepository? repository})
    : repository = repository ?? IsarJobModuleRepository();

  Future<List<JobModuleSavedDraft>> list({
    required AppUser actor,
    required int moduleLocalId,
  }) async {
    _requireApprovedActor(actor, 'read saved module drafts');
    final events = await isar.auditEvents
        .filter()
        .entityTypeEqualTo(_moduleConflictType)
        .and()
        .performedByUidEqualTo(actor.uid)
        .sortByTimestampDesc()
        .findAll();
    final result = <JobModuleSavedDraft>[];
    for (final event in events) {
      final manifest = event.after;
      if (manifest?['moduleLocalId'] != moduleLocalId) continue;
      result.add(await _read(actor, event));
    }
    return result;
  }

  Future<JobModuleSavedDraft> _read(
    AppUser actor,
    AuditEvent manifestEvent,
  ) async {
    if (manifestEvent.performedByUid != actor.uid) {
      throw StateError('This draft belongs to another account.');
    }
    final manifest = manifestEvent.after;
    if (manifest == null ||
        manifest['protocolVersion'] != 1 ||
        manifest['moduleLocalId'] is! int ||
        manifest['reason'] is! String ||
        manifest['evidenceSha256'] is! String ||
        manifest['chunkCount'] is! int ||
        (manifest['chunkCount'] as int) < 1) {
      throw StateError(
        'Saved draft evidence needs repair; no work was changed.',
      );
    }
    final events = await isar.auditEvents
        .filter()
        .entityTypeEqualTo(_moduleConflictPartType)
        .and()
        .entityIdEqualTo(manifestEvent.entityId)
        .and()
        .performedByUidEqualTo(actor.uid)
        .findAll();
    final count = manifest['chunkCount'] as int;
    if (events.length != count) {
      throw StateError(
        'Saved draft evidence is incomplete; no work was changed.',
      );
    }
    final chunks = <int, String>{};
    for (final event in events) {
      final part = event.after;
      if (part == null ||
          part['protocolVersion'] != 1 ||
          part['chunkIndex'] is! int ||
          (part['chunkIndex'] as int) < 0 ||
          (part['chunkIndex'] as int) >= count ||
          part['evidenceSha256'] != manifest['evidenceSha256'] ||
          part['bytesBase64'] is! String ||
          chunks.containsKey(part['chunkIndex'])) {
        throw StateError(
          'Saved draft evidence conflicts; no work was changed.',
        );
      }
      chunks[part['chunkIndex'] as int] = part['bytesBase64'] as String;
    }
    final bytes = base64Decode(
      List.generate(count, (index) => chunks[index]!).join(),
    );
    if (sha256.convert(bytes).toString() != manifest['evidenceSha256']) {
      throw StateError('Saved draft checksum failed; no work was changed.');
    }
    final evidenceJson = utf8.decode(bytes);
    final evidence = jsonDecode(evidenceJson);
    if (evidence is! Map ||
        evidence['protocolVersion'] != 1 ||
        evidence['actorUid'] != actor.uid ||
        evidence['moduleLocalId'] != manifest['moduleLocalId'] ||
        evidence['reason'] != manifest['reason'] ||
        evidence['attempted'] is! Map) {
      throw StateError('Saved draft identity conflicts; no work was changed.');
    }
    return JobModuleSavedDraft(
      conflictId: manifestEvent.entityId,
      moduleLocalId: manifest['moduleLocalId'] as int,
      actorUid: actor.uid,
      savedAt: manifestEvent.timestamp,
      reason: manifest['reason'] as String,
      evidenceJson: evidenceJson,
    );
  }

  Future<JobModuleDraftReview> review({
    required AppUser actor,
    required JobModuleSavedDraft saved,
  }) async {
    _requireApprovedActor(actor, 'review saved module work');
    if (saved.actorUid != actor.uid) {
      throw StateError('This draft belongs to another account.');
    }
    final manifest = await isar.auditEvents
        .filter()
        .entityTypeEqualTo(_moduleConflictType)
        .and()
        .entityIdEqualTo(saved.conflictId)
        .and()
        .performedByUidEqualTo(actor.uid)
        .findAll();
    if (manifest.length != 1) {
      throw StateError('Saved draft identity is ambiguous.');
    }
    final persisted = await _read(actor, manifest.single);
    final current = await isar.jobModuleInstances.get(persisted.moduleLocalId);
    if (current == null) {
      throw StateError(
        'The module is no longer present. The draft is retained.',
      );
    }
    _requireCanSaveModuleWork(actor, current);
    final problem = !current.isOpenForWork
        ? 'The module is closed for editing. The draft is retained.'
        : await _moduleParentSaveProblem(current);
    return JobModuleDraftReview(persisted, current, blockingReason: problem);
  }

  Future<JobModuleInstance> apply({
    required AppUser actor,
    required JobModuleDraftReview review,
  }) async {
    if (review.saved.actorUid != actor.uid) {
      throw StateError('This draft belongs to another account.');
    }
    final candidate = review.recoveryCandidate();
    await repository.saveModule(
      candidate,
      actor: actor,
      expectedBaseline: review.baseline,
      recoveredConflictId: review.saved.conflictId,
      auditContext: AuditContext(
        performedByUid: actor.uid,
        performedByName: actor.name,
        summary:
            'Explicitly reapplied reviewed module work from retained draft.',
      ),
    );
    return candidate;
  }
}

Future<void> _saveNativeModuleWithPreimage(
  IsarJobModuleRepository repository,
  JobModuleInstance module, {
  AppUser? actor,
  AuditContext? auditContext,
  JobModuleSaveBaseline? expectedBaseline,
  String? recoveredConflictId,
}) async {
  final isCreate = module.id == Isar.autoIncrement;
  if (actor == null) {
    throw StateError('Actor is required when saving planned-job modules.');
  }
  repository._verifyActor?.call(actor);
  if (isCreate) {
    _requireCanAddModuleDuringExecution(actor);
    _requireRuntimeModuleAddControl(actor, module);
  } else {
    _requireCanSaveModuleWork(actor, module);
  }

  Map<String, dynamic>? beforeSnapshot;
  Map<String, dynamic>? afterSnapshot;
  String? entityId;
  JobModuleSaveConflict? conflict;

  await isar.writeTxn(() async {
    JobModuleInstance? existing;
    if (!isCreate && module.id != Isar.autoIncrement) {
      existing = await isar.jobModuleInstances.get(module.id);
      beforeSnapshot = existing?.toAuditMap();
    }

    String? problem;
    if (!isCreate) {
      if (existing == null) {
        problem = 'module-missing';
      } else if (existing.version < 1 ||
          expectedBaseline == null ||
          !expectedBaseline.matches(existing) ||
          expectedBaseline.localId != module.id ||
          expectedBaseline.version != module.version) {
        problem = 'reviewed-module-changed';
      } else if (existing.isDeleted || !existing.isOpenForWork) {
        problem = 'module-closed';
      } else if (!_sameModuleNonWorkFields(existing, module)) {
        problem = 'module-identity-or-governance-changed';
      } else {
        _requireCanSaveModuleWork(actor, existing);
        try {
          _requireOpenForWork(existing, 'save module work');
          _requireOpenForWork(module, 'save module work');
        } on StateError {
          problem = 'module-work-needs-review';
        }
      }
    }
    problem ??= await _moduleParentSaveProblem(existing ?? module);
    repository._verifyActor?.call(actor);
    if (problem != null) {
      conflict = await _retainModuleSaveConflict(
        attempted: module,
        current: existing,
        baseline: expectedBaseline,
        actor: actor,
        reason: problem,
      );
      repository._verifyActor?.call(actor);
      return;
    }

    if (recoveredConflictId != null) {
      final original = await isar.auditEvents
          .filter()
          .entityTypeEqualTo(_moduleConflictType)
          .and()
          .entityIdEqualTo(recoveredConflictId)
          .and()
          .performedByUidEqualTo(actor.uid)
          .findAll();
      if (original.length != 1 ||
          original.single.after?['moduleLocalId'] != module.id) {
        throw StateError('Saved draft identity could not be verified.');
      }
      final saved = await JobModuleDraftRecovery(
        repository: repository,
      )._read(actor, original.single);
      final attempted = saved.evidence['attempted'] as Map;
      final candidate = jobModuleLocalSnapshot(module);
      for (final key in _moduleEditableFields.where(
        (key) => !{'updatedAt', 'updatedByUid', 'updatedByName'}.contains(key),
      )) {
        if (jsonEncode(candidate[key]) != jsonEncode(attempted[key])) {
          throw StateError(
            'The recovery must use the exact reviewed saved work.',
          );
        }
      }
    }

    repository._verifyActor?.call(actor);

    _normaliseModuleForUserSave(
      module,
      markUnsynced: true,
      auditContext: auditContext,
      incrementVersion: existing != null,
    );

    await isar.jobModuleInstances.put(module);
    repository._verifyActor?.call(actor);
    afterSnapshot = module.toAuditMap();
    entityId = module.firestoreId ?? module.id.toString();
    if (recoveredConflictId != null) {
      await isar.auditEvents.put(
        AuditEvent(
          entityType: _moduleConflictResolvedType,
          entityId: recoveredConflictId,
          action: AuditAction.resolve,
          performedByUid: actor.uid,
          performedByName: actor.name,
          summary: 'Reviewed saved work reapplied; original conflict retained.',
          after: {
            'protocolVersion': 1,
            'moduleLocalId': module.id,
            'appliedVersion': module.version,
            'appliedPreimageSha256': sha256
                .convert(
                  utf8.encode(jsonEncode(jobModuleLocalSnapshot(module))),
                )
                .toString(),
          },
        ),
      );
    }
    repository._verifyActor?.call(actor);
  });
  repository._verifyActor?.call(actor);

  // Throw only after the transaction commits the losing draft. Throwing
  // inside the transaction would roll back precisely the recovery evidence.
  if (conflict != null) throw conflict!;

  if (auditContext != null && afterSnapshot != null && entityId != null) {
    final action = beforeSnapshot == null
        ? AuditAction.create
        : AuditAction.update;
    final auditRepo = repository._auditRepo;
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
