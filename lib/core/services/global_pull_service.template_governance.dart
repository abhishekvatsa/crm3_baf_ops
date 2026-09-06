part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// TEMPLATE GOVERNANCE (PAGINATED)
// ─────────────────────────────────────────────────────────────

extension _GlobalPullTemplateGovernance on GlobalPullService {
  Future<void> _pullTemplatePackages(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedPackages(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final packages = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (packages.isEmpty) break;

      for (final remote in packages) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _templateGovernanceRepo
                .applyTombstoneFromPackageRemote(remote);
            _recordTombstoneApplyResult('template package', remote, result);
            continue;
          }

          final applyResult = await _templateGovernanceRepo
              .applyPackageFromRemote(remote);
          _recordRemoteApplyResult('template package', remote, applyResult);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template package pull error: $e');
        }
      }

      if (packages.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullTemplateVersions(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedVersions(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final versions = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (versions.isEmpty) break;

      for (final remote in versions) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _templateGovernanceRepo
                .applyTombstoneFromVersionRemote(remote);
            _recordTombstoneApplyResult('template version', remote, result);
            continue;
          }

          final applyResult = await _templateGovernanceRepo
              .applyVersionFromRemote(remote);
          _recordRemoteApplyResult('template version', remote, applyResult);
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template version pull error: $e');
        }
      }

      if (versions.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }

  Future<void> _pullTemplatePublishAudits(
    DateTime? lastSync,
    DateTime through,
  ) async {
    DocumentSnapshot? startAfter;

    while (true) {
      final result = await _firestoreTemplateGovernance.getUpdatedAudits(
        since: lastSync,
        through: through,
        limit: GlobalPullService._pageSize,
        startAfter: startAfter,
      );

      final audits = result.records;
      _validateFetchedServerBoundary(result.lastDoc, through);
      startAfter = result.lastDoc;

      if (audits.isEmpty) break;

      for (final remote in audits) {
        try {
          if (remote.firestoreId == null) continue;
          if (remote.isDeleted) {
            final result = await _templateGovernanceRepo
                .applyTombstoneFromAuditRemote(remote);
            _recordTombstoneApplyResult(
              'template publish audit',
              remote,
              result,
            );
            continue;
          }
          final applyResult = await _templateGovernanceRepo
              .applyAuditFromRemote(remote);
          _recordRemoteApplyResult(
            'template publish audit',
            remote,
            applyResult,
          );
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template publish audit pull error: $e');
        }
      }

      if (audits.length < GlobalPullService._pageSize) break;
      if (startAfter == null) break;
    }
  }
}
