part of 'sync_service.dart';

extension _SyncServiceDirectivesAbnormalities on SyncService {
  Future<void> _syncDirectives() async {
    final unsynced = await _directiveRepo.getUnsyncedDirectives();
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
        entityType: 'directive',
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

      final remoteList = await _firestoreDirective.getDirectivesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <OperationalDirective>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'directive',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for directive ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for directive ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'directive ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (remote != null &&
            !record.isDeleted &&
            !remote.isDeleted &&
            syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

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
          try {
            await _directiveRepo.applyTombstoneFromDirectiveRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for directive ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for directive ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'directive',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local directive ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreDirective.batchUpsertDirectives(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'directive',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Directive batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _directiveRepo.markDirectivesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  Future<void> _syncAbnormalityTypes() async {
    final unsynced = await _abnormalityRepo.getUnsyncedTypes();
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
        entityType: 'abnormality_type',
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

      final remoteList = await _firestoreAbnormality.getTypesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <AbnormalityType>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'abnormality_type',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for abnormality type ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for abnormality type ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'abnormality type ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (remote != null &&
            !record.isDeleted &&
            !remote.isDeleted &&
            syncPersistedSnapshotsEquivalent(record.toMap(), remote.toMap())) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

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
          try {
            await _abnormalityRepo.applyTombstoneFromTypeRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for abnormality type ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for abnormality type ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'abnormality_type',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local abnormality type ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreAbnormality.batchUpsertTypes(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'abnormality_type',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Abnormality type batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markTypesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  Future<void> _syncChargeAbnormalities() async {
    final unsynced = await _abnormalityRepo.getUnsyncedAbnormalities();
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
        entityType: 'charge_abnormality',
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

      final remoteList = await _firestoreAbnormality
          .getAbnormalitiesByFirestoreIds(firestoreIds);
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToCreate = <ChargeAbnormality>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'charge_abnormality',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for charge abnormality ${record.id}',
          );
          debugPrint(
            '❌ Missing firestoreId for charge abnormality ${record.id}',
          );
          continue;
        }

        _checkClockDrift(record.updatedAt, 'charge abnormality ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (remote == null) {
          if (record.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
          } else {
            recordsToCreate.add(record);
          }
          continue;
        }

        if (record.isDeleted) {
          if (remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          await _pushGovernedChargeAbnormalityMutation(
            local: record,
            remote: remote,
            operation: ChargeAbnormalityMutationOperation.softDelete,
          );
          continue;
        }

        if (remote.isDeleted) {
          try {
            await _abnormalityRepo.applyTombstoneFromAbnormalityRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for charge abnormality ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for charge abnormality ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (_governedChargeAbnormalityStateMatches(record, remote)) {
          final snapshot = _syncPushSnapshot(record);
          await _abnormalityRepo.markAbnormalitiesSyncedIfUnchanged([snapshot]);
          await _abnormalityRepo.updateAbnormalityFromRemote(remote);
          lastSuccessCount++;
          continue;
        }

        if (_isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'charge_abnormality',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local charge abnormality ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        await _pushGovernedChargeAbnormalityMutation(
          local: record,
          remote: remote,
          operation: ChargeAbnormalityMutationOperation.update,
        );
      }

      bool pushSuccess = false;

      if (recordsToCreate.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestoreAbnormality.batchUpsertAbnormalities(
              recordsToCreate,
            );
          });

          pushSuccess = true;
          lastSuccessCount += recordsToCreate.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToCreate.length;
          _recordPushFailuresForBatch(
            entityType: 'charge_abnormality',
            records: recordsToCreate,
            error: e,
          );
          debugPrint('❌ Charge abnormality create sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToCreate));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markAbnormalitiesSyncedIfUnchanged(
          snapshotsToMark,
        );
      }
    }
  }

  Future<void> _pushGovernedChargeAbnormalityMutation({
    required ChargeAbnormality local,
    required ChargeAbnormality remote,
    required ChargeAbnormalityMutationOperation operation,
  }) async {
    final firestoreId = local.firestoreId!;
    if (local.version != remote.version + 1) {
      await _recordPushConflict(
        entityType: 'charge_abnormality',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote.toAuditMap(),
      );
      lastFailureCount++;
      debugPrint(
        '⚠️ GOVERNED PUSH CONFLICT: Charge abnormality $firestoreId '
        'does not have a single-version local mutation.',
      );
      return;
    }

    final requestId = _abnormalityCommands.deterministicSyncRequestId(
      operation: operation,
      abnormalityId: firestoreId,
      localVersion: local.version,
    );
    final snapshot = _syncPushSnapshot(local);
    final rawReason =
        operation == ChargeAbnormalityMutationOperation.softDelete
            ? local.deleteReason ?? 'Deleted charge abnormality'
            : 'Synchronised privileged charge-abnormality update';

    try {
      ChargeAbnormalityMutationResult? result;
      await _retry(
        () async {
          if (operation == ChargeAbnormalityMutationOperation.softDelete) {
            result = await _abnormalityCommands.softDelete(
              abnormality: local,
              expectedVersion: remote.version,
              reason: rawReason,
              requestId: requestId,
            );
            return;
          }
          result = await _abnormalityCommands.update(
            abnormality: local,
            expectedVersion: remote.version,
            reason: rawReason,
            requestId: requestId,
          );
        },
        shouldRetry: (error) {
          return error is! ChargeAbnormalityMutationException ||
              !error.isDurableRejection;
        },
      );
      final accepted = result;
      if (accepted == null) {
        throw const ChargeAbnormalityMutationException(
          code: 'internal',
          message: 'The governed abnormality mutation returned no result.',
          reasonCode: 'abnormality-response-missing',
        );
      }
      await _abnormalityRepo.markAbnormalitiesSyncedIfUnchanged([snapshot]);
      await _abnormalityRepo.updateAbnormalityFromRemote(accepted.abnormality);
      lastSuccessCount++;
    } catch (error, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'charge_abnormality',
        entityId: firestoreId,
        error: error,
      );
      debugPrint(
        '❌ Governed charge abnormality ${operation.wireName} failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _governedChargeAbnormalityStateMatches(
    ChargeAbnormality local,
    ChargeAbnormality remote,
  ) {
    return local.version == remote.version &&
        local.abnormalityTypeId == remote.abnormalityTypeId &&
        local.severity == remote.severity &&
        encodeAffectedAssets(local.affectedAssets) ==
            encodeAffectedAssets(remote.affectedAssets) &&
        local.component == remote.component &&
        local.observedReason == remote.observedReason &&
        local.description == remote.description &&
        local.possibleRootReasonCategory == remote.possibleRootReasonCategory &&
        local.possibleRootReasonNotes == remote.possibleRootReasonNotes &&
        local.reannealingStatus == remote.reannealingStatus &&
        local.reannealedToChargeNo == remote.reannealedToChargeNo &&
        local.isDeleted == remote.isDeleted &&
        local.deleteReason == remote.deleteReason;
  }
}
