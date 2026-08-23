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
      final convergedRecords = <TemplatePackage>[];

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

        if (remote != null &&
            !record.isDeleted &&
            !remote.isDeleted &&
            syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          convergedRecords.add(record);
          lastSuccessCount++;
          continue;
        }

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            convergedRecords.add(record);
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          final result = await _templateGovernanceRepo
              .applyTombstoneFromPackageRemote(remote);
          if (await _retainHoldForPreservedLocalTombstone(
            result: result,
            entityType: 'template_package',
            record: record,
            entityLabel: 'template package',
          )) {
            continue;
          }
          await _resolveRecheckedPermanentRejectionsForRecords(
            entityType: 'template_package',
            records: <TemplatePackage>[record],
            evidence:
                'The canonical remote template-package tombstone was adopted locally.',
          );
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
        convergedRecords.addAll(recordsToPush);
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markPackagesSyncedIfUnchanged(
          snapshotsToMark,
        );
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'template_package',
          records: convergedRecords,
          evidence:
              'The remote template-package write or exact readback completed and the local snapshot was reconciled.',
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
      final convergedRecords = <TemplateVersion>[];

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

        if (remote != null &&
            !record.isDeleted &&
            !remote.isDeleted &&
            syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          convergedRecords.add(record);
          lastSuccessCount++;
          continue;
        }

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            convergedRecords.add(record);
            lastSuccessCount++;
            continue;
          }
          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          final result = await _templateGovernanceRepo
              .applyTombstoneFromVersionRemote(remote);
          if (await _retainHoldForPreservedLocalTombstone(
            result: result,
            entityType: 'template_version',
            record: record,
            entityLabel: 'template version',
          )) {
            continue;
          }
          await _resolveRecheckedPermanentRejectionsForRecords(
            entityType: 'template_version',
            records: <TemplateVersion>[record],
            evidence:
                'The canonical remote template-version tombstone was adopted locally.',
          );
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

        final archiveReplayed = await _tryPushDecomposedTemplateVersionArchive(
          record,
          remote,
        );
        if (archiveReplayed) {
          lastSuccessCount++;
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          convergedRecords.add(record);
          debugPrint(
            '🪜 Replayed collapsed TemplateVersion draft→archive lifecycle: '
            '${record.firestoreId} (package=${record.packageFirestoreId ?? 'unknown'})',
          );
          continue;
        }

        final publishReplayed = await _tryPushDecomposedTemplateVersion(
          record,
          remote,
        );
        if (publishReplayed) {
          lastSuccessCount++;
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          convergedRecords.add(record);
          debugPrint(
            '🪜 Replayed collapsed TemplateVersion draft→publish lifecycle: '
            '${record.firestoreId} (package=${record.packageFirestoreId ?? 'unknown'})',
          );
          continue;
        }

        // If a first replay step committed but the lifecycle step did not, the
        // remote may now be a draft. Falling through to the standard batch
        // path lets the existing push either complete the now single-hop
        // update or surface the remaining rejection.
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
        convergedRecords.addAll(recordsToPush);
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markVersionsSyncedIfUnchanged(
          snapshotsToMark,
        );
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'template_version',
          records: convergedRecords,
          evidence:
              'The governed version replay, remote write, or exact readback completed and the local snapshot was reconciled.',
        );
      }
    }
  }

  List<_TemplateVersionReplayStep> _templateVersionArchiveReplayPlan(
    TemplateVersion local,
    TemplateVersion? remote,
  ) {
    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null) return const [];
    if (local.isDeleted || local.status != TemplateVersionStatus.archived) {
      return const [];
    }

    if (remote == null) {
      if (!_canReplayTemplateVersionArchiveForCurrentUser(
        local,
        requiresDraftCreate: true,
      )) {
        return const [];
      }
      if (local.version <= 1 || _cleanText(local.contentHash) == null) {
        return const [];
      }
      return const [
        _TemplateVersionReplayStep.createDraft,
        _TemplateVersionReplayStep.archive,
      ];
    }

    if (_cleanText(remote.firestoreId) != firestoreId) return const [];
    if (remote.isDeleted) return const [];
    if (remote.status != TemplateVersionStatus.draft) return const [];
    if (!_canReplayTemplateVersionArchiveForCurrentUser(
      local,
      requiresDraftCreate: false,
    )) {
      return const [];
    }
    if (local.version <= remote.version) return const [];
    if (_templateVersionPinnedFieldDiff(local, remote) != 'none') {
      return const [];
    }
    final payloadDiff = _templateVersionDraftPayloadDiff(local, remote);
    if (_cleanText(local.contentHash) == null) return const [];
    if (payloadDiff != 'none') {
      final predecessorVersion = local.version - 1;
      if (predecessorVersion <= remote.version) return const [];
      return const [
        _TemplateVersionReplayStep.updateDraft,
        _TemplateVersionReplayStep.archive,
      ];
    }

    return const [_TemplateVersionReplayStep.archive];
  }

  bool _canReplayTemplateVersionArchiveForCurrentUser(
    TemplateVersion local, {
    required bool requiresDraftCreate,
  }) {
    final currentUid = _cleanText(FirebaseAuth.instance.currentUser?.uid);
    final updatedByUid = _cleanText(local.updatedByUid);
    if (currentUid == null || updatedByUid == null) return false;
    if (updatedByUid != currentUid) return false;

    if (!requiresDraftCreate) return true;
    final createdByUid = _cleanText(local.createdByUid);
    return createdByUid != null && createdByUid == currentUid;
  }

  bool _remoteTemplateVersionArchiveAlreadySatisfied(
    TemplateVersion local,
    TemplateVersion? remote,
  ) {
    if (remote == null || local.isDeleted || remote.isDeleted) return false;
    if (local.status != TemplateVersionStatus.archived ||
        remote.status != TemplateVersionStatus.archived) {
      return false;
    }
    if (local.version != remote.version) return false;
    if (_cleanText(local.contentHash) != _cleanText(remote.contentHash)) {
      return false;
    }
    if (_cleanText(local.updatedByUid) != _cleanText(remote.updatedByUid)) {
      return false;
    }
    if (_templateVersionPinnedFieldDiff(local, remote) != 'none') return false;
    return _templateVersionDraftPayloadDiff(local, remote) == 'none';
  }

  Future<bool> _tryPushDecomposedTemplateVersionArchive(
    TemplateVersion local,
    TemplateVersion? remote,
  ) async {
    if (_remoteTemplateVersionArchiveAlreadySatisfied(local, remote)) {
      return true;
    }

    final plan = _templateVersionArchiveReplayPlan(local, remote);
    if (plan.isEmpty) return false;

    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null) return false;

    var expectedDraftVersion = remote?.version;
    try {
      for (final step in plan) {
        if (step == _TemplateVersionReplayStep.createDraft) {
          final stepData = _templateVersionDraftReplayCreateData(local);
          final receipt = await _applyTemplateVersionLifecycleReplayStep(
            firestoreId,
            stepData,
            () => _firestoreTemplateGovernance
                .createRemoteTemplateVersionDraftReplayStepForSync(
                  firestoreId,
                  stepData,
                ),
          );
          expectedDraftVersion = receipt.version;
          continue;
        }
        if (step == _TemplateVersionReplayStep.updateDraft) {
          final predecessorVersion = expectedDraftVersion;
          if (predecessorVersion == null) {
            throw StateError(
              'TemplateVersion draft update replay is missing its expected remote version.',
            );
          }
          final stepData = _templateVersionDraftReplayUpdateData(local);
          final receipt = await _applyTemplateVersionLifecycleReplayStep(
            firestoreId,
            stepData,
            () => _firestoreTemplateGovernance
                .applyRemoteTemplateVersionDraftUpdateReplayStepForSync(
                  firestoreId,
                  stepData,
                  expectedDraftVersion: predecessorVersion,
                ),
          );
          expectedDraftVersion = receipt.version;
          continue;
        }

        final predecessorVersion = expectedDraftVersion;
        if (predecessorVersion == null) {
          throw StateError(
            'TemplateVersion archive replay is missing its expected remote draft version.',
          );
        }
        final stepData = _templateVersionArchiveReplayStepData(local);
        await _applyTemplateVersionLifecycleReplayStep(
          firestoreId,
          stepData,
          () => _firestoreTemplateGovernance
              .applyRemoteTemplateVersionArchiveReplayStepForSync(
                firestoreId,
                stepData,
                expectedDraftVersion: predecessorVersion,
              ),
        );
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Decomposed TemplateVersion archive replay did not fully complete '
        'for $firestoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
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
    if (_remoteTemplateVersionPublishAlreadySatisfied(local, remote)) {
      return true;
    }

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
          final stepData = _templateVersionDraftReplayCreateData(local);
          await _applyTemplateVersionLifecycleReplayStep(
            firestoreId,
            stepData,
            () => _firestoreTemplateGovernance
                .createRemoteTemplateVersionDraftReplayStepForSync(
                  firestoreId,
                  stepData,
                ),
          );
        } else {
          final stepData = _templateVersionPublishReplayStepData(local);
          await _applyTemplateVersionLifecycleReplayStep(
            firestoreId,
            stepData,
            () => _firestoreTemplateGovernance
                .applyRemoteTemplateVersionPublishReplayStepForSync(
                  firestoreId,
                  stepData,
                ),
          );
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

  bool _remoteTemplateVersionPublishAlreadySatisfied(
    TemplateVersion local,
    TemplateVersion? remote,
  ) {
    if (remote == null || local.isDeleted || remote.isDeleted) return false;
    if (local.status != TemplateVersionStatus.published ||
        remote.status != TemplateVersionStatus.published) {
      return false;
    }
    if (_templateVersionPinnedFieldDiff(local, remote) != 'none') return false;
    if (_templateVersionDraftPayloadDiff(local, remote) != 'none') return false;
    return syncLifecycleReplayOutcomeMatches(
      remote.toMap(),
      _templateVersionPublishReplayStepData(local),
    );
  }

  Future<TemplateVersion> _applyTemplateVersionLifecycleReplayStep(
    String firestoreId,
    Map<String, dynamic> stepData,
    Future<void> Function() writeStep,
  ) async {
    TemplateVersion? observed;
    try {
      await _retry(writeStep);
    } catch (_) {
      observed = await _readTemplateVersionLifecycleReplayReceipt(firestoreId);
      if (!syncLifecycleReplayOutcomeMatches(observed?.toMap(), stepData)) {
        rethrow;
      }
      debugPrint(
        'TemplateVersion lifecycle replay for $firestoreId was confirmed by '
        'readback after an uncertain write outcome.',
      );
    }

    observed ??= await _readTemplateVersionLifecycleReplayReceipt(firestoreId);
    if (!syncLifecycleReplayOutcomeMatches(observed?.toMap(), stepData)) {
      throw StateError(
        'TemplateVersion lifecycle replay for $firestoreId did not match '
        'exact post-write readback.',
      );
    }
    return observed!;
  }

  Future<TemplateVersion?> _readTemplateVersionLifecycleReplayReceipt(
    String firestoreId,
  ) async {
    final records = await _firestoreTemplateGovernance
        .getVersionsByFirestoreIds(<String>[firestoreId]);
    if (records.length > 1) {
      throw StateError(
        'TemplateVersion lifecycle replay readback returned duplicate records '
        'for $firestoreId.',
      );
    }
    return records.isEmpty ? null : records.single;
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

  Map<String, dynamic> _templateVersionDraftReplayUpdateData(
    TemplateVersion local,
  ) {
    final draftData = _templateVersionDraftReplayCreateData(local);
    draftData
      ..['updatedByUid'] = local.updatedByUid
      ..['updatedByName'] = local.updatedByName
      ..['updatedAt'] = local.updatedAt.toIso8601String()
      ..['version'] = local.version - 1;
    return draftData;
  }

  Map<String, dynamic> _templateVersionArchiveReplayStepData(
    TemplateVersion local,
  ) {
    final full = local.toMap();
    return <String, dynamic>{
      'status': TemplateVersionStatus.archived.name,
      'contentHash': full['contentHash'],
      'closureReviewConfirmed': full['closureReviewConfirmed'],
      'closureCriticalModuleCount': full['closureCriticalModuleCount'],
      'closureReviewConfirmedByUid': full['closureReviewConfirmedByUid'],
      'closureReviewConfirmedByName': full['closureReviewConfirmedByName'],
      'closureReviewConfirmedAt': full['closureReviewConfirmedAt'],
      'updatedByUid': full['updatedByUid'],
      'updatedByName': full['updatedByName'],
      'updatedAt': full['updatedAt'],
      'version': full['version'],
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

  bool _templatePublishAuditMatchesRemote(
    TemplatePublishAudit local,
    TemplatePublishAudit remote,
  ) {
    return _cleanText(local.firestoreId) == _cleanText(remote.firestoreId) &&
        _cleanText(local.packageFirestoreId) ==
            _cleanText(remote.packageFirestoreId) &&
        _cleanText(local.versionFirestoreId) ==
            _cleanText(remote.versionFirestoreId) &&
        local.action == remote.action &&
        _cleanText(local.performedByUid) == _cleanText(remote.performedByUid) &&
        _cleanText(local.performedByName) ==
            _cleanText(remote.performedByName) &&
        _sameInstant(local.performedAt, remote.performedAt) &&
        _sameInstant(local.updatedAt, remote.updatedAt) &&
        _cleanText(local.reason) == _cleanText(remote.reason) &&
        _cleanText(local.beforeHash) == _cleanText(remote.beforeHash) &&
        _cleanText(local.afterHash) == _cleanText(remote.afterHash) &&
        _cleanText(local.payloadSnapshotJson) ==
            _cleanText(remote.payloadSnapshotJson) &&
        _cleanText(local.metadataJson) == _cleanText(remote.metadataJson) &&
        local.version == remote.version &&
        local.schemaVersion == remote.schemaVersion &&
        local.isDeleted == remote.isDeleted;
  }

  bool _templateLifecycleAuditSnapshotMatchesRemote(
    TemplatePublishAudit audit,
    TemplateVersion remoteVersion,
  ) {
    final rawSnapshot = _cleanText(audit.payloadSnapshotJson);
    if (rawSnapshot == null) return false;
    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map<String, dynamic>) return false;
      final map = decoded;
      final snapshotUpdatedAt =
          readRequiredPersistedDateTime(
            map['updatedAt'],
            field: 'updatedAt',
            source: 'template lifecycle audit snapshot',
          ).toUtc();
      return _cleanText(map['firestoreId']?.toString()) ==
              _cleanText(remoteVersion.firestoreId) &&
          _cleanText(map['packageFirestoreId']?.toString()) ==
              _cleanText(remoteVersion.packageFirestoreId) &&
          map['status']?.toString() == remoteVersion.status.name &&
          _cleanText(map['contentHash']?.toString()) ==
              _cleanText(remoteVersion.contentHash) &&
          map['version'] == remoteVersion.version &&
          _cleanText(map['updatedByUid']?.toString()) ==
              _cleanText(remoteVersion.updatedByUid) &&
          _sameInstant(snapshotUpdatedAt, remoteVersion.updatedAt);
    } on Object {
      return false;
    }
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
        return remoteVersion.status == TemplateVersionStatus.archived &&
            _templateLifecycleAuditSnapshotMatchesRemote(audit, remoteVersion);
      case TemplatePublishAuditAction.restored:
        return remoteVersion.status == TemplateVersionStatus.draft &&
            _templateLifecycleAuditSnapshotMatchesRemote(audit, remoteVersion);
      case TemplatePublishAuditAction.created:
      case TemplatePublishAuditAction.edited:
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
      final remoteById = <String, TemplatePublishAudit>{
        for (final remote in remoteList)
          if (remote.firestoreId != null) remote.firestoreId!: remote,
      };
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
      final convergedRecords = <TemplatePublishAudit>[];

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

        final existingRemote = remoteById[record.firestoreId];
        if (existingRemote != null) {
          if (_templatePublishAuditMatchesRemote(record, existingRemote)) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            convergedRecords.add(record);
            lastSuccessCount++;
          } else {
            lastFailureCount++;
            _recordPushFailureDetail(
              entityType: 'template_publish_audit',
              entityId: record.firestoreId!,
              error:
                  'Remote audit identity exists with different immutable evidence; local audit was not marked synced.',
            );
            debugPrint(
              '⛔ Template publish audit collision preserved locally: '
              '${record.firestoreId}',
            );
          }
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
        convergedRecords.addAll(recordsToPush);
      }
      if (snapshotsToMark.isNotEmpty) {
        await _templateGovernanceRepo.markAuditsSyncedIfUnchanged(
          snapshotsToMark,
        );
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'template_publish_audit',
          records: convergedRecords,
          evidence:
              'The immutable publish audit was accepted remotely or matched exact remote evidence and was reconciled locally.',
        );
      }
    }
  }
}

enum _TemplateVersionReplayStep { createDraft, updateDraft, publish, archive }
