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
