part of 'template_governance_provider.dart';

extension _ReviewedPublication on IsarTemplateGovernanceRepository {
  Future<TemplateVersion> _publishReviewedVersion(
    TemplateVersion reviewed, {
    required AppUser actor,
    String? reason,
  }) async {
    _requireTemplateGovernor(actor, 'publish template versions');
    final candidate = _detachedPublicationVersion(reviewed);
    if (!candidate.isDraft || candidate.isDeleted) {
      throw StateError('Only active drafts can be published.');
    }
    if (candidate.firestoreId != null && !candidate.isSynced) {
      throw StateError(
        'A saved TemplateVersion draft must sync successfully before it can be published.',
      );
    }
    return isar.writeTxn(() async {
      final current = candidate.firestoreId == null
          ? await isar.templateVersions.get(candidate.id)
          : await isar.templateVersions
                .filter()
                .firestoreIdEqualTo(candidate.firestoreId)
                .findFirst();
      if (current == null && candidate.firestoreId != null) {
        throw StateError(
          'The reviewed draft is missing. Reload before publishing.',
        );
      }
      if (current != null) {
        if (current.version != candidate.version ||
            current.versionNumber != candidate.versionNumber ||
            current.packageFirestoreId != candidate.packageFirestoreId ||
            current.computeContentHash() != candidate.computeContentHash() ||
            current.updatedAt.toUtc() != candidate.updatedAt.toUtc() ||
            current.isDeleted ||
            !current.isDraft ||
            !current.isSynced) {
          throw StateError(
            'The reviewed draft changed. Newer content and lifecycle evidence were preserved; reload before publishing.',
          );
        }
        await _requireRestoredDraftAuditSynced(
          current,
          actionLabel: 'published',
        );
        candidate.id = current.id;
      }
      _validateTemplateVersionSnapshotForPublish(candidate);
      final package = candidate.packageFirestoreId == null
          ? null
          : await isar.templatePackages
                .filter()
                .firestoreIdEqualTo(candidate.packageFirestoreId)
                .findFirst();
      if (package != null &&
          candidate.versionNumber <= package.latestVersionNumber) {
        throw StateError(
          'Publish this older draft as a new linked version; its saved number cannot be changed.',
        );
      }
      final beforeHash = candidate.contentHash;
      final now = DateTime.now();
      candidate
        ..status = TemplateVersionStatus.published
        ..publishedByUid = actor.uid
        ..publishedByName = actor.name
        ..publishedAt = now
        ..updatedAt = now;
      candidate.refreshContentHash();
      _normalizeVersionForUserSave(candidate, actor: actor, markUnsynced: true);
      final audit = _newAudit(
        action: TemplatePublishAuditAction.published,
        actor: actor,
        version: candidate,
        reason: reason,
        beforeHash: beforeHash,
        afterHash: candidate.contentHash,
        firestoreId: _auditFirestoreIdFactory(),
      );
      await isar.templateVersions.put(candidate);
      await isar.templatePublishAudits.put(audit);
      if (package != null) {
        package
          ..activeVersionFirestoreId = candidate.firestoreId
          ..latestVersionNumber = candidate.versionNumber;
        _normalizePackageForUserSave(package, actor: actor, markUnsynced: true);
        await isar.templatePackages.put(package);
      }
      return candidate;
    });
  }
}

TemplateVersion _detachedPublicationVersion(TemplateVersion source) {
  return TemplateVersion()
    ..id = source.id
    ..firestoreId = source.firestoreId
    ..packageFirestoreId = source.packageFirestoreId
    ..isSynced = source.isSynced
    ..version = source.version
    ..schemaVersion = source.schemaVersion
    ..versionNumber = source.versionNumber
    ..versionLabel = source.versionLabel
    ..status = source.status
    ..sourceVersionFirestoreId = source.sourceVersionFirestoreId
    ..contentHash = source.contentHash
    ..jobTemplateSnapshotJson = source.jobTemplateSnapshotJson
    ..moduleSnapshotsJson = source.moduleSnapshotsJson
    ..fieldDefinitionsJson = source.fieldDefinitionsJson
    ..checklistJson = source.checklistJson
    ..releaseNotes = source.releaseNotes
    ..changeSummary = source.changeSummary
    ..closureReviewConfirmed = source.closureReviewConfirmed
    ..closureCriticalModuleCount = source.closureCriticalModuleCount
    ..closureReviewConfirmedByUid = source.closureReviewConfirmedByUid
    ..closureReviewConfirmedByName = source.closureReviewConfirmedByName
    ..closureReviewConfirmedAt = source.closureReviewConfirmedAt
    ..createdByUid = source.createdByUid
    ..createdByName = source.createdByName
    ..updatedByUid = source.updatedByUid
    ..updatedByName = source.updatedByName
    ..publishedByUid = source.publishedByUid
    ..publishedByName = source.publishedByName
    ..publishedAt = source.publishedAt
    ..retiredByUid = source.retiredByUid
    ..retiredByName = source.retiredByName
    ..retiredAt = source.retiredAt
    ..retireReason = source.retireReason
    ..minAppVersion = source.minAppVersion
    ..isDeleted = source.isDeleted
    ..deletedAt = source.deletedAt
    ..deletedByUid = source.deletedByUid
    ..deletedByName = source.deletedByName
    ..deleteReason = source.deleteReason
    ..createdAt = source.createdAt
    ..updatedAt = source.updatedAt
    ..targetRefs = List<String>.from(source.targetRefs)
    ..deviceTagRefs = List<String>.from(source.deviceTagRefs)
    ..safetyClass = source.safetyClass
    ..safetyGatePolicyJson = source.safetyGatePolicyJson
    ..procedureRefs = List<String>.from(source.procedureRefs)
    ..operationalStatePreconditions = List<String>.from(
      source.operationalStatePreconditions,
    )
    ..metadataJson = source.metadataJson;
}
