import '../data/template_governance_model.dart';

enum TemplatePublicationReadinessCode {
  ready,
  packageMissing,
  packageMissingIdentity,
  packageDeleted,
  packageNotActive,
  packageNotSynced,
  activeVersionMissing,
  versionMissing,
  versionMissingIdentity,
  versionDeleted,
  versionNotPublished,
  versionNotSynced,
  versionPackageMismatch,
  versionNotActive,
  versionHashMissing,
  versionHashMismatch,
  publishAuditMissing,
  publishAuditNotSynced,
  publishAuditPackageMismatch,
  publishAuditHashMismatch,
}

class TemplatePublicationReadinessDecision {
  final TemplatePublicationReadinessCode code;
  final TemplatePublishAudit? matchingAudit;
  final String? detail;

  const TemplatePublicationReadinessDecision({
    required this.code,
    this.matchingAudit,
    this.detail,
  });

  bool get isReady => code == TemplatePublicationReadinessCode.ready;

  String get operatorMessage {
    switch (code) {
      case TemplatePublicationReadinessCode.ready:
        return 'The active published version and its publication audit are synchronized and ready for governed assignment.';
      case TemplatePublicationReadinessCode.packageMissing:
        return 'The selected TemplatePackage could not be reloaded. Pull latest governance data and try again.';
      case TemplatePublicationReadinessCode.packageMissingIdentity:
        return 'The selected TemplatePackage has no stable Firestore identity.';
      case TemplatePublicationReadinessCode.packageDeleted:
        return 'The selected TemplatePackage has been deleted and cannot be assigned.';
      case TemplatePublicationReadinessCode.packageNotActive:
        return 'Only an active TemplatePackage can be assigned.';
      case TemplatePublicationReadinessCode.packageNotSynced:
        return 'The active TemplatePackage is not yet remotely confirmed. Complete synchronization before assignment.';
      case TemplatePublicationReadinessCode.activeVersionMissing:
        return 'The active TemplatePackage does not identify an active TemplateVersion.';
      case TemplatePublicationReadinessCode.versionMissing:
        return 'The selected TemplateVersion could not be reloaded. Pull latest governance data and try again.';
      case TemplatePublicationReadinessCode.versionMissingIdentity:
        return 'The selected TemplateVersion has no stable Firestore identity.';
      case TemplatePublicationReadinessCode.versionDeleted:
        return 'The selected TemplateVersion has been deleted and cannot be assigned.';
      case TemplatePublicationReadinessCode.versionNotPublished:
        return 'Only a published TemplateVersion can be assigned.';
      case TemplatePublicationReadinessCode.versionNotSynced:
        return 'The published TemplateVersion is not yet remotely confirmed. Complete synchronization before assignment.';
      case TemplatePublicationReadinessCode.versionPackageMismatch:
        return 'The selected TemplateVersion does not belong to the active TemplatePackage.';
      case TemplatePublicationReadinessCode.versionNotActive:
        return 'The selected TemplateVersion is not the package active version. Historical assignment is not enabled.';
      case TemplatePublicationReadinessCode.versionHashMissing:
        return 'The published TemplateVersion has no governed content hash.';
      case TemplatePublicationReadinessCode.versionHashMismatch:
        return 'The stored TemplateVersion content hash does not match its frozen governance payload.';
      case TemplatePublicationReadinessCode.publishAuditMissing:
        return 'No matching publication audit is available for the active TemplateVersion.';
      case TemplatePublicationReadinessCode.publishAuditNotSynced:
        return 'The matching publication audit is still awaiting remote confirmation.';
      case TemplatePublicationReadinessCode.publishAuditPackageMismatch:
        return 'The publication audit does not identify the active TemplatePackage.';
      case TemplatePublicationReadinessCode.publishAuditHashMismatch:
        return 'The publication audit hash does not match the active TemplateVersion.';
    }
  }

  String get diagnosticMessage {
    final suffix = detail?.trim();
    return suffix == null || suffix.isEmpty
        ? operatorMessage
        : '$operatorMessage Detail: $suffix';
  }
}

TemplatePublicationReadinessDecision evaluateTemplatePublicationReadiness({
  required TemplatePackage? package,
  required TemplateVersion? version,
  required Iterable<TemplatePublishAudit> audits,
}) {
  if (package == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.packageMissing,
    );
  }

  final packageId = _clean(package.firestoreId);
  if (packageId == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.packageMissingIdentity,
    );
  }
  if (package.isDeleted) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.packageDeleted,
    );
  }
  if (package.lifecycleStatus != TemplatePackageLifecycleStatus.active) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.packageNotActive,
    );
  }
  if (!package.isSynced) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.packageNotSynced,
    );
  }

  final activeVersionId = _clean(package.activeVersionFirestoreId);
  if (activeVersionId == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.activeVersionMissing,
    );
  }

  if (version == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionMissing,
    );
  }
  final versionId = _clean(version.firestoreId);
  if (versionId == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionMissingIdentity,
    );
  }
  if (version.isDeleted) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionDeleted,
    );
  }
  if (!version.isPublished) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionNotPublished,
    );
  }
  if (!version.isSynced) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionNotSynced,
    );
  }
  if (_clean(version.packageFirestoreId) != packageId) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionPackageMismatch,
    );
  }
  if (versionId != activeVersionId) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionNotActive,
    );
  }

  final storedHash = _clean(version.contentHash);
  if (storedHash == null) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionHashMissing,
    );
  }
  final computedHash = version.computeContentHash();
  if (storedHash != computedHash) {
    return TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.versionHashMismatch,
      detail: 'stored=$storedHash computed=$computedHash',
    );
  }

  final publishedAudits = audits
      .where(
        (audit) =>
            !audit.isDeleted &&
            audit.action == TemplatePublishAuditAction.published &&
            _clean(audit.versionFirestoreId) == versionId,
      )
      .toList(growable: false)
    ..sort((a, b) => b.performedAt.compareTo(a.performedAt));

  if (publishedAudits.isEmpty) {
    return const TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.publishAuditMissing,
    );
  }

  final hashMatchingAudits = publishedAudits
      .where((audit) => _clean(audit.afterHash) == storedHash)
      .toList(growable: false);
  if (hashMatchingAudits.isEmpty) {
    return TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.publishAuditHashMismatch,
      matchingAudit: publishedAudits.first,
      detail:
          'expected=$storedHash latestAuditAfterHash=${_clean(publishedAudits.first.afterHash) ?? 'missing'}',
    );
  }

  final packageMatchingAudits = hashMatchingAudits
      .where((audit) => _clean(audit.packageFirestoreId) == packageId)
      .toList(growable: false);
  if (packageMatchingAudits.isEmpty) {
    return TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.publishAuditPackageMismatch,
      matchingAudit: hashMatchingAudits.first,
      detail:
          'expected=$packageId auditPackage=${_clean(hashMatchingAudits.first.packageFirestoreId) ?? 'missing'}',
    );
  }

  TemplatePublishAudit? syncedAudit;
  for (final audit in packageMatchingAudits) {
    if (audit.isSynced) {
      syncedAudit = audit;
      break;
    }
  }
  if (syncedAudit == null) {
    return TemplatePublicationReadinessDecision(
      code: TemplatePublicationReadinessCode.publishAuditNotSynced,
      matchingAudit: packageMatchingAudits.first,
    );
  }

  return TemplatePublicationReadinessDecision(
    code: TemplatePublicationReadinessCode.ready,
    matchingAudit: syncedAudit,
  );
}

TemplateVersion? activeTemplateVersionForPackage({
  required TemplatePackage package,
  required Iterable<TemplateVersion> versions,
}) {
  final activeId = _clean(package.activeVersionFirestoreId);
  if (activeId == null) return null;
  for (final version in versions) {
    if (_clean(version.firestoreId) == activeId) return version;
  }
  return null;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
