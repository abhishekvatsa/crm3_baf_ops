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

      final inserts = <TemplatePackage>[];
      final updates = <TemplatePackage>[];
      final tombstones = <TemplatePackage>[];

      for (final remote in packages) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _templateGovernanceRepo.getPackageByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) tombstones.add(remote);
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('template package', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template package pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _templateGovernanceRepo
            .applyTombstoneFromPackageRemote(remote);
        _recordTombstoneApplyResult('template package', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _templateGovernanceRepo.insertPackageFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _templateGovernanceRepo.updatePackageFromRemote(remote);
        lastUpdated++;
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

      final inserts = <TemplateVersion>[];
      final updates = <TemplateVersion>[];
      final tombstones = <TemplateVersion>[];

      for (final remote in versions) {
        try {
          if (remote.firestoreId == null) continue;

          final local = await _templateGovernanceRepo.getVersionByFirestoreId(
            remote.firestoreId!,
          );

          if (remote.isDeleted) {
            if (local != null) tombstones.add(remote);
            continue;
          }

          if (local == null) {
            inserts.add(remote);
          } else {
            final bool isLocalUnsynced = !local.isSynced;
            final bool isRemoteNewer = _isRemoteNewer(local, remote);

            if (!isLocalUnsynced && local.updatedAt.isAfter(remote.updatedAt)) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && !isRemoteNewer) {
              lastSkipped++;
              continue;
            }

            if (isLocalUnsynced && isRemoteNewer) {
              _logPullConflict('template version', local, remote);
              continue;
            }

            updates.add(remote);
          }
        } catch (e) {
          lastSkipped++;
          _hadRecordProcessingError = true;
          debugPrint('⚠️ Template version pull error: $e');
        }
      }

      for (final remote in tombstones) {
        final result = await _templateGovernanceRepo
            .applyTombstoneFromVersionRemote(remote);
        _recordTombstoneApplyResult('template version', remote, result);
      }

      for (final record in inserts) {
        record.isSynced = true;
        await _templateGovernanceRepo.insertVersionFromRemote(record);
        lastInserted++;
      }

      for (final remote in updates) {
        await _templateGovernanceRepo.updateVersionFromRemote(remote);
        lastUpdated++;
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
          final local = await _templateGovernanceRepo.getAuditByFirestoreId(
            remote.firestoreId!,
          );
          if (local != null) {
            lastSkipped++;
            continue;
          }
          remote.isSynced = true;
          await _templateGovernanceRepo.insertAuditFromRemote(remote);
          lastInserted++;
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
