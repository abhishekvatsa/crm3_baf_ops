part of 'sync_service.dart';

extension _SyncServiceTemplateGovernance on SyncService {
  Future<void> _syncTemplateGovernance() async {
    await _syncTemplatePackages();
    await _syncTemplateVersions();
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

        // 70A: local-first publish replay. Firestore rules correctly deny
        // create-as-published. If the device created a draft and published it
        // before Firestore ever saw the draft, sync must create the draft first
        // and then apply the draft -> published update. Do not fall back to the
        // ordinary batch path for any remote-missing non-draft version.
        if (remote == null && !record.isDeleted && !record.isDraft) {
          if (record.isPublished) {
            final replayed = await _tryPushDecomposedTemplateVersion(record);
            if (replayed) {
              skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
              lastSuccessCount++;
            } else {
              lastFailureCount++;
              _recordPushFailureDetail(
                entityType: 'template_version',
                entityId: record.firestoreId!,
                error:
                    'Remote TemplateVersion is missing and local status is '
                    '${record.status.name}; publish replay could not complete.',
              );
            }
            continue;
          }

          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'template_version',
            entityId: record.firestoreId!,
            error:
                'Remote TemplateVersion is missing and local status is '
                '${record.status.name}; direct create-as-${record.status.name} '
                'is intentionally blocked by Firestore rules.',
          );
          continue;
        }

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

  Future<bool> _tryPushDecomposedTemplateVersion(
    TemplateVersion local,
  ) async {
    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null || local.isDeleted || !local.isPublished) {
      return false;
    }

    if (local.version <= 1) {
      debugPrint(
        '⚠️ TemplateVersion publish replay refused for $firestoreId because '
        'local.version=${local.version} cannot be decomposed into '
        'draft + published versions.',
      );
      return false;
    }

    final currentUid = _cleanText(FirebaseAuth.instance.currentUser?.uid);
    final createdByUid = _cleanText(local.createdByUid);
    final publishedByUid = _cleanText(local.publishedByUid);
    final updatedByUid = _cleanText(local.updatedByUid);
    if (currentUid == null ||
        createdByUid == null ||
        publishedByUid == null ||
        updatedByUid == null) {
      debugPrint(
        '⚠️ TemplateVersion publish replay refused for $firestoreId because '
        'created/published/updated uid metadata is incomplete.',
      );
      return false;
    }

    // Firestore rules bind draft create updatedByUid/createdByUid and publish
    // publishedByUid/updatedByUid to request.auth.uid. Cross-actor collapsed
    // publish is therefore not replayed silently; it must surface as a sync
    // diagnostic instead of forging the missing server chronology.
    if (createdByUid != currentUid ||
        publishedByUid != currentUid ||
        updatedByUid != currentUid) {
      debugPrint(
        '⚠️ TemplateVersion publish replay refused for $firestoreId because '
        'the collapsed lifecycle is not same-user under request.auth.uid.',
      );
      return false;
    }

    if (local.publishedAt == null || _cleanText(local.contentHash) == null) {
      debugPrint(
        '⚠️ TemplateVersion publish replay refused for $firestoreId because '
        'publishedAt/contentHash is missing.',
      );
      return false;
    }

    try {
      await _retry(() async {
        await _firestoreTemplateGovernance
            .createRemoteVersionDraftReplayForSync(
          firestoreId,
          _templateVersionDraftReplayCreateData(local),
        );
      });

      await _retry(() async {
        await _firestoreTemplateGovernance
            .applyRemoteVersionPublishReplayStepForSync(
          firestoreId,
          _templateVersionPublishReplayStepData(local),
        );
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Decomposed TemplateVersion publish replay did not fully complete '
        'for $firestoreId (${local.versionLabel ?? local.versionNumber}): '
        '$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Map<String, dynamic> _templateVersionDraftReplayCreateData(
    TemplateVersion local,
  ) {
    final draft = Map<String, dynamic>.from(local.toMap());
    final createdAt = draft['createdAt'];
    final currentUid = _cleanText(FirebaseAuth.instance.currentUser?.uid);

    draft
      ..['status'] = TemplateVersionStatus.draft.name
      ..['contentHash'] = null
      ..['publishedByUid'] = null
      ..['publishedByName'] = null
      ..['publishedAt'] = null
      ..['retiredByUid'] = null
      ..['retiredByName'] = null
      ..['retiredAt'] = null
      ..['retireReason'] = null
      ..['deletedAt'] = null
      ..['deletedByUid'] = null
      ..['deletedByName'] = null
      ..['deleteReason'] = null
      ..['updatedByUid'] = currentUid
      ..['version'] = local.version - 1;

    if (createdAt != null) {
      draft['updatedAt'] = createdAt;
    }

    return draft;
  }

  Map<String, dynamic> _templateVersionPublishReplayStepData(
    TemplateVersion local,
  ) {
    final full = local.toMap();
    return <String, dynamic>{
      'status': TemplateVersionStatus.published.name,
      'contentHash': full['contentHash'],
      'closureReviewConfirmed': full['closureReviewConfirmed'],
      'closureCriticalModuleCount': full['closureCriticalModuleCount'],
      'closureReviewConfirmedByUid': full['closureReviewConfirmedByUid'],
      'closureReviewConfirmedByName': full['closureReviewConfirmedByName'],
      'closureReviewConfirmedAt': full['closureReviewConfirmedAt'],
      'publishedByUid': full['publishedByUid'],
      'publishedByName': full['publishedByName'],
      'publishedAt': full['publishedAt'],
      'updatedAt': full['publishedAt'] ?? full['updatedAt'],
      'updatedByUid': full['publishedByUid'],
      'updatedByName': full['publishedByName'],
      'version': full['version'],
    };
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
