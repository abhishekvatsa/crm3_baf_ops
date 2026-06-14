part of 'sync_service.dart';

extension _SyncServiceTemplateGovernance on SyncService {
  Future<void> _syncTemplateGovernance() async {
    // Version lifecycle must reach Firestore before a package points at an
    // active version or a publish audit is allowed to leave the device.
    await _syncTemplateVersions();
    await _syncTemplatePackages();
    await _syncTemplatePublishAudits();
  }

  Future<void> _syncTemplatePackages() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedPackages();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_package',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreTemplateGovernance
          .getPackagesByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <TemplatePackage>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_package',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template package ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template package ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template package ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          await _templateGovernanceRepo.applyTombstoneFromPackageRemote(remote);
          lastSuccessCount++;
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template_package',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertPackages(
              recordsToPush,
            );
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_package',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template package batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markPackagesSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  Future<void> _syncTemplateVersions() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedVersions();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_version',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestoreTemplateGovernance
          .getVersionsByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <TemplateVersion>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_version',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template version ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template version ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template version ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          await _templateGovernanceRepo.applyTombstoneFromVersionRemote(remote);
          lastSuccessCount++;
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template_version',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          continue;
        }

        final replayed = await _tryPushDecomposedTemplateVersion(
          record,
          remote,
        );
        if (replayed) {
          lastSuccessCount++;
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          debugPrint(
            '🪜 Replayed collapsed TemplateVersion draft→publish lifecycle: '
            '${record.firestoreId} (package=${record.packageFirestoreId ?? 'unknown'})',
          );
          continue;
        }

        // If a first replay step committed but the publish step did not, the
        // remote may now be a draft. Falling through to the standard batch
        // path lets the existing push either complete the now single-hop
        // draft→published update or surface the remaining rejection.
        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertVersions(
              recordsToPush,
            );
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_version',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template version batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markVersionsSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  List<_TemplateVersionReplayStep> _templateVersionLifecycleReplayPlan(
    TemplateVersion local,
    TemplateVersion? remote,
  ) {
    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null) return const [];
    if (local.isDeleted || local.status != TemplateVersionStatus.published) {
      return const [];
    }

    // This replay is deliberately limited to the proven lifecycle-collapse
    // failure: the tablet has a locally published version, but Firestore never
    // observed the draft predecessor. Normal draft creates and existing
    // draft→published updates stay on the standard batch path.
    if (remote == null) {
      if (!_canReplayTemplateVersionPublishForCurrentUser(local)) {
        return const [];
      }
      if (local.version <= 1) return const [];
      if (_cleanText(local.contentHash) == null ||
          _cleanText(local.publishedByUid) == null ||
          local.publishedAt == null) {
        return const [];
      }
      return const [
        _TemplateVersionReplayStep.createDraft,
        _TemplateVersionReplayStep.publish,
      ];
    }

    if (_cleanText(remote.firestoreId) != firestoreId) return const [];
    if (remote.isDeleted) return const [];
    if (remote.status != TemplateVersionStatus.draft) return const [];
    if (!_canReplayTemplateVersionPublishForCurrentUser(local)) {
      return const [];
    }
    if (local.version <= remote.version) return const [];
    if (_templateVersionPinnedFieldDiff(local, remote) != 'none') {
      return const [];
    }
    if (_templateVersionDraftPayloadDiff(local, remote) != 'none') {
      return const [];
    }
    if (_cleanText(local.contentHash) == null || local.publishedAt == null) {
      return const [];
    }

    return const [_TemplateVersionReplayStep.publish];
  }

  bool _canReplayTemplateVersionPublishForCurrentUser(TemplateVersion local) {
    final currentUid = _cleanText(FirebaseAuth.instance.currentUser?.uid);
    final createdByUid = _cleanText(local.createdByUid);
    final publishedByUid = _cleanText(local.publishedByUid);
    if (currentUid == null || createdByUid == null || publishedByUid == null) {
      return false;
    }

    // Firestore create and publish rules bind createdByUid/updatedByUid and
    // publishedByUid to request.auth.uid. Cross-actor reconstruction would need
    // a server-mediated design, not a client-side replay shortcut.
    return createdByUid == currentUid && publishedByUid == currentUid;
  }

  Future<bool> _tryPushDecomposedTemplateVersion(
    TemplateVersion local,
    TemplateVersion? remote,
  ) async {
    if (_shouldRestoreRemoteDraftPayloadBeforePublishReplay(local, remote)) {
      _restoreRemoteDraftPayloadForPublishReplay(local, remote!);
      await _templateGovernanceRepo.batchUpsertVersions(<TemplateVersion>[
        local,
      ]);
      debugPrint(
        '🧭 Restored Firestore draft payload before TemplateVersion publish replay: '
        '${local.firestoreId}',
      );
    }

    final plan = _templateVersionLifecycleReplayPlan(local, remote);
    if (plan.isEmpty) return false;

    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null) return false;

    try {
      for (final step in plan) {
        if (step == _TemplateVersionReplayStep.createDraft) {
          await _retry(() async {
            await _firestoreTemplateGovernance
                .createRemoteTemplateVersionDraftReplayStepForSync(
                  firestoreId,
                  _templateVersionDraftReplayCreateData(local),
                );
          });
        } else {
          await _retry(() async {
            await _firestoreTemplateGovernance
                .applyRemoteTemplateVersionPublishReplayStepForSync(
                  firestoreId,
                  _templateVersionPublishReplayStepData(local),
                );
          });
        }
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Decomposed TemplateVersion publish replay did not fully complete '
        'for $firestoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  bool _shouldRestoreRemoteDraftPayloadBeforePublishReplay(
    TemplateVersion local,
    TemplateVersion? remote,
  ) {
    if (remote == null || remote.isDeleted || local.isDeleted) return false;
    if (local.status != TemplateVersionStatus.published ||
        remote.status != TemplateVersionStatus.draft) {
      return false;
    }
    if (!_canReplayTemplateVersionPublishForCurrentUser(local)) return false;
    if (local.version <= remote.version) return false;
    if (_templateVersionPinnedFieldDiff(local, remote) != 'none') return false;
    return _templateVersionDraftPayloadDiff(local, remote) != 'none';
  }

  void _restoreRemoteDraftPayloadForPublishReplay(
    TemplateVersion local,
    TemplateVersion remote,
  ) {
    local
      ..jobTemplateSnapshotJson = remote.jobTemplateSnapshotJson
      ..moduleSnapshotsJson = remote.moduleSnapshotsJson
      ..fieldDefinitionsJson = remote.fieldDefinitionsJson
      ..checklistJson = remote.checklistJson
      ..targetRefs = List<String>.from(remote.targetRefs)
      ..deviceTagRefs = List<String>.from(remote.deviceTagRefs)
      ..safetyClass = remote.safetyClass
      ..safetyGatePolicyJson = remote.safetyGatePolicyJson
      ..procedureRefs = List<String>.from(remote.procedureRefs)
      ..operationalStatePreconditions = List<String>.from(
        remote.operationalStatePreconditions,
      )
      ..isSynced = false;
    local.refreshContentHash();
  }

  Map<String, dynamic> _templateVersionDraftReplayCreateData(
    TemplateVersion local,
  ) {
    final full = local.toMap();
    return <String, dynamic>{
      'firestoreId': full['firestoreId'],
      'packageFirestoreId': full['packageFirestoreId'],
      'versionNumber': full['versionNumber'],
      'versionLabel': full['versionLabel'],
      'status': TemplateVersionStatus.draft.name,
      'sourceVersionFirestoreId': full['sourceVersionFirestoreId'],
      'contentHash': null,
      'jobTemplateSnapshotJson': full['jobTemplateSnapshotJson'],
      'moduleSnapshotsJson': full['moduleSnapshotsJson'],
      'fieldDefinitionsJson': full['fieldDefinitionsJson'],
      'checklistJson': full['checklistJson'],
      'releaseNotes': full['releaseNotes'],
      'changeSummary': full['changeSummary'],
      'closureReviewConfirmed': full['closureReviewConfirmed'],
      'closureCriticalModuleCount': full['closureCriticalModuleCount'],
      'closureReviewConfirmedByUid': full['closureReviewConfirmedByUid'],
      'closureReviewConfirmedByName': full['closureReviewConfirmedByName'],
      'closureReviewConfirmedAt': full['closureReviewConfirmedAt'],
      'createdByUid': full['createdByUid'],
      'createdByName': full['createdByName'],
      'updatedByUid': full['createdByUid'],
      'updatedByName': full['createdByName'],
      'publishedByUid': null,
      'publishedByName': null,
      'publishedAt': null,
      'retiredByUid': null,
      'retiredByName': null,
      'retiredAt': null,
      'retireReason': null,
      'minAppVersion': full['minAppVersion'],
      'isDeleted': false,
      'deletedAt': null,
      'deletedByUid': null,
      'deletedByName': null,
      'deleteReason': null,
      'version': local.version - 1,
      'schemaVersion': full['schemaVersion'],
      'createdAt': full['createdAt'],
      'updatedAt': local.createdAt.toIso8601String(),
      'targetRefs': full['targetRefs'],
      'deviceTagRefs': full['deviceTagRefs'],
      'safetyClass': full['safetyClass'],
      'safetyGatePolicyJson': full['safetyGatePolicyJson'],
      'procedureRefs': full['procedureRefs'],
      'operationalStatePreconditions': full['operationalStatePreconditions'],
      'metadataJson': full['metadataJson'],
    };
  }

  Map<String, dynamic> _templateVersionPublishReplayStepData(
    TemplateVersion local,
  ) {
    final full = local.toMap();
    return <String, dynamic>{
      'status': TemplateVersionStatus.published.name,
      'contentHash': full['contentHash'],
      'versionLabel': full['versionLabel'],
      'releaseNotes': full['releaseNotes'],
      'changeSummary': full['changeSummary'],
      'minAppVersion': full['minAppVersion'],
      'metadataJson': full['metadataJson'],
      'publishedByUid': full['publishedByUid'],
      'publishedByName': full['publishedByName'],
      'publishedAt': full['publishedAt'],
      'updatedByUid': full['publishedByUid'],
      'updatedByName': full['publishedByName'],
      'updatedAt': full['publishedAt'] ?? full['updatedAt'],
      'version': full['version'],
    };
  }

  String _templateVersionPinnedFieldDiff(
    TemplateVersion local,
    TemplateVersion remote,
  ) {
    final diffs = <String>[];
    if (local.firestoreId != remote.firestoreId) diffs.add('firestoreId');
    if (local.packageFirestoreId != remote.packageFirestoreId) {
      diffs.add('packageFirestoreId');
    }
    if (local.versionNumber != remote.versionNumber) {
      diffs.add('versionNumber');
    }
    if (local.sourceVersionFirestoreId != remote.sourceVersionFirestoreId) {
      diffs.add('sourceVersionFirestoreId');
    }
    if (local.createdByUid != remote.createdByUid) diffs.add('createdByUid');
    if (!_sameInstant(local.createdAt, remote.createdAt)) {
      diffs.add('createdAt');
    }
    if (local.isDeleted != remote.isDeleted) diffs.add('isDeleted');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _templateVersionDraftPayloadDiff(
    TemplateVersion local,
    TemplateVersion remote,
  ) {
    final diffs = <String>[];
    if (local.jobTemplateSnapshotJson != remote.jobTemplateSnapshotJson) {
      diffs.add('jobTemplateSnapshotJson');
    }
    if (local.moduleSnapshotsJson != remote.moduleSnapshotsJson) {
      diffs.add('moduleSnapshotsJson');
    }
    if (local.fieldDefinitionsJson != remote.fieldDefinitionsJson) {
      diffs.add('fieldDefinitionsJson');
    }
    if (local.checklistJson != remote.checklistJson) {
      diffs.add('checklistJson');
    }
    if (local.targetRefs.join('\u0001') != remote.targetRefs.join('\u0001')) {
      diffs.add('targetRefs');
    }
    if (local.deviceTagRefs.join('\u0001') !=
        remote.deviceTagRefs.join('\u0001')) {
      diffs.add('deviceTagRefs');
    }
    if (local.safetyClass != remote.safetyClass) diffs.add('safetyClass');
    if (local.safetyGatePolicyJson != remote.safetyGatePolicyJson) {
      diffs.add('safetyGatePolicyJson');
    }
    if (local.procedureRefs.join('\u0001') !=
        remote.procedureRefs.join('\u0001')) {
      diffs.add('procedureRefs');
    }
    if (local.operationalStatePreconditions.join('\u0001') !=
        remote.operationalStatePreconditions.join('\u0001')) {
      diffs.add('operationalStatePreconditions');
    }

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  bool _templatePublishAuditRemoteDependencySatisfied(
    TemplatePublishAudit audit,
    TemplateVersion? remoteVersion,
  ) {
    if (remoteVersion == null || remoteVersion.isDeleted) return false;
    switch (audit.action) {
      case TemplatePublishAuditAction.published:
        return remoteVersion.status == TemplateVersionStatus.published ||
            remoteVersion.status == TemplateVersionStatus.retired ||
            remoteVersion.status == TemplateVersionStatus.archived;
      case TemplatePublishAuditAction.retired:
        return remoteVersion.status == TemplateVersionStatus.retired ||
            remoteVersion.status == TemplateVersionStatus.archived;
      case TemplatePublishAuditAction.archived:
        return remoteVersion.status == TemplateVersionStatus.archived;
      case TemplatePublishAuditAction.created:
      case TemplatePublishAuditAction.edited:
      case TemplatePublishAuditAction.restored:
        return true;
    }
  }

  Future<void> _syncTemplatePublishAudits() async {
    final unsynced = await _templateGovernanceRepo.getUnsyncedAudits();
    if (unsynced.isEmpty) {
      return;
    }

    for (var i = 0; i < unsynced.length; i += 500) {
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'template_publish_audit',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((e) => e.firestoreId)
              .whereType<String>()
              .toList();
      final remoteList = await _firestoreTemplateGovernance
          .getAuditsByFirestoreIds(firestoreIds);
      final remoteIds =
          remoteList.map((e) => e.firestoreId).whereType<String>().toSet();
      final versionIds = activeBatchRecords
          .map((record) => record.versionFirestoreId)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList(growable: false);
      final remoteVersions = await _firestoreTemplateGovernance
          .getVersionsByFirestoreIds(versionIds);
      final remoteVersionById = <String, TemplateVersion>{
        for (final version in remoteVersions)
          if (version.firestoreId != null) version.firestoreId!: version,
      };

      final recordsToPush = <TemplatePublishAudit>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_publish_audit',
            entityId: 'local:${record.id}',
            error:
                'Missing firestoreId for template publish audit ${record.id}',
          );
          debugPrint(
            '❌ Missing firestoreId for template publish audit ${record.id}',
          );
          continue;
        }

        if (remoteIds.contains(record.firestoreId)) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

        final remoteVersion = remoteVersionById[record.versionFirestoreId];
        if (!_templatePublishAuditRemoteDependencySatisfied(
          record,
          remoteVersion,
        )) {
          debugPrint(
            '⏸️ Holding TemplateVersion audit until remote lifecycle is confirmed: '
            '${record.firestoreId} (action=${record.action.name}, '
            'version=${record.versionFirestoreId ?? 'unknown'})',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;
      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreTemplateGovernance.batchUpsertAudits(recordsToPush);
          });
          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'template_publish_audit',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template publish audit batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];
      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markAuditsSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }
}

enum _TemplateVersionReplayStep { createDraft, publish }
