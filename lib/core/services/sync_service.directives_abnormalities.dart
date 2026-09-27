part of 'sync_service.dart';

extension _SyncServiceDirectivesAbnormalities on SyncService {
  Future<void> _syncDirectives() async {
    final ordinaryOwner = OrdinaryDirectiveCommands(
      actorUid: () {
        _checkRunCurrent();
        return _rejectionOwnerUidLookup();
      },
    );
    final outcomes = _directiveRepo is IsarDirectiveRepository
        ? await ordinaryOwner.checkAll(runGuard: _runGuard)
        : (succeeded: 0, failed: 0);
    _checkRunCurrent();
    lastSuccessCount += outcomes.succeeded;
    lastFailureCount += outcomes.failed;
    final ownedIds = _directiveRepo is IsarDirectiveRepository
        ? await ordinaryOwner.ownedDirectiveIds()
        : const <String>{};
    _checkRunCurrent();
    final unsynced = <OperationalDirective>[];
    for (final record in await _guardedPushAwait(
      () async => _directiveRepo.getUnsyncedDirectives(),
    )) {
      _checkRunCurrent();
      if (_directiveRepo is IsarDirectiveRepository &&
          record.firestoreId != null &&
          ownedIds.contains(record.firestoreId!)) {
        continue;
      }
      unsynced.add(record);
    }
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 1) {
      _checkRunCurrent();
      final batchRecords = unsynced.sublist(i, i + 1);
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'directive',
        records: batchRecords,
      );
      _checkRunCurrent();
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds = activeBatchRecords
          .map((e) => e.firestoreId)
          .whereType<String>()
          .toList();

      final List<OperationalDirective> remoteList;
      try {
        remoteList = await _firestoreDirective.getDirectivesByFirestoreIds(
          firestoreIds,
        );
        _checkRunCurrent();
      } catch (error) {
        rethrowIfSyncRunMustAbort(error);
        _checkRunCurrent();
        lastFailureCount += activeBatchRecords.length;
        _recordPushFailuresForBatch(
          entityType: 'directive',
          records: activeBatchRecords,
          error: error,
        );
        continue;
      }
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <OperationalDirective>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];
      final convergedRecords = <OperationalDirective>[];

      for (final record in activeBatchRecords) {
        _checkRunCurrent();
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
          convergedRecords.add(record);
          lastSuccessCount++;
          continue;
        }

        if (_directiveRepo is IsarDirectiveRepository &&
            !isGovernedBurnerRoundDirectiveId(record.firestoreId)) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'directive',
            entityId: record.firestoreId!,
            error:
                'Older saved directive evidence has no immutable original command. It is preserved for reviewed reconciliation; automatic upload is held.',
          );
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
          try {
            final result = await _directiveRepo
                .applyTombstoneFromDirectiveRemote(remote);
            _checkRunCurrent();
            if (await _guardedPushAwait(
              () async => _retainHoldForPreservedLocalTombstone(
                result: result,
                entityType: 'directive',
                record: record,
                entityLabel: 'directive',
              ),
            )) {
              continue;
            }
            await _resolveRecheckedPermanentRejectionsForRecords(
              entityType: 'directive',
              records: <OperationalDirective>[record],
              evidence:
                  'The canonical remote directive tombstone was adopted locally.',
            );
            _checkRunCurrent();
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for directive ${record.id}',
            );
          } catch (e, stackTrace) {
            rethrowIfSyncRunMustAbort(e);
            _checkRunCurrent();
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
          _checkRunCurrent();
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
            _checkRunCurrent();
          });
          _checkRunCurrent();

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          rethrowIfSyncRunMustAbort(e);
          _checkRunCurrent();
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
        convergedRecords.addAll(recordsToPush);
      }

      if (snapshotsToMark.isNotEmpty) {
        await _directiveRepo.markDirectivesSyncedIfUnchanged(snapshotsToMark);
        _checkRunCurrent();
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'directive',
          records: convergedRecords,
          evidence:
              'The remote directive write or exact readback completed and the local snapshot was reconciled.',
        );
        _checkRunCurrent();
      }
    }
  }

  Future<void> _syncAbnormalityTypes() async {
    final unsynced = await _abnormalityRepo.getUnsyncedTypes();
    _checkRunCurrent();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      _checkRunCurrent();
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'abnormality_type',
        records: batchRecords,
      );
      _checkRunCurrent();
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds = activeBatchRecords
          .map((e) => e.firestoreId)
          .whereType<String>()
          .toList();

      final remoteList = await _firestoreAbnormality.getTypesByFirestoreIds(
        firestoreIds,
      );
      _checkRunCurrent();
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <AbnormalityType>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];
      final convergedRecords = <AbnormalityType>[];

      for (final record in activeBatchRecords) {
        _checkRunCurrent();
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
          try {
            final result = await _abnormalityRepo.applyTombstoneFromTypeRemote(
              remote,
            );
            _checkRunCurrent();
            if (await _guardedPushAwait(
              () async => _retainHoldForPreservedLocalTombstone(
                result: result,
                entityType: 'abnormality_type',
                record: record,
                entityLabel: 'abnormality type',
              ),
            )) {
              continue;
            }
            await _resolveRecheckedPermanentRejectionsForRecords(
              entityType: 'abnormality_type',
              records: <AbnormalityType>[record],
              evidence:
                  'The canonical remote abnormality-type tombstone was adopted locally.',
            );
            _checkRunCurrent();
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for abnormality type ${record.id}',
            );
          } catch (e, stackTrace) {
            rethrowIfSyncRunMustAbort(e);
            _checkRunCurrent();
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
          _checkRunCurrent();
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
            _checkRunCurrent();
          });
          _checkRunCurrent();

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          rethrowIfSyncRunMustAbort(e);
          _checkRunCurrent();
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
        convergedRecords.addAll(recordsToPush);
      }

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markTypesSyncedIfUnchanged(snapshotsToMark);
        _checkRunCurrent();
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'abnormality_type',
          records: convergedRecords,
          evidence:
              'The remote abnormality-type write or exact readback completed and the local snapshot was reconciled.',
        );
        _checkRunCurrent();
      }
    }
  }

  Future<void> _syncChargeAbnormalities() async {
    final unsynced = await _abnormalityRepo.getUnsyncedAbnormalities();
    _checkRunCurrent();
    if (unsynced.isEmpty) {
      return;
    }

    _sortDeletesFirst(unsynced);

    for (var i = 0; i < unsynced.length; i += 500) {
      _checkRunCurrent();
      final batchRecords = unsynced.sublist(
        i,
        i + 500 > unsynced.length ? unsynced.length : i + 500,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'charge_abnormality',
        records: batchRecords,
      );
      _checkRunCurrent();
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds = activeBatchRecords
          .map((e) => e.firestoreId)
          .whereType<String>()
          .toList();

      final remoteList = await _firestoreAbnormality
          .getAbnormalitiesByFirestoreIds(firestoreIds);
      _checkRunCurrent();
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];
      final convergedRecords = <ChargeAbnormality>[];

      for (final record in activeBatchRecords) {
        _checkRunCurrent();
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
            convergedRecords.add(record);
            lastSuccessCount++;
          } else {
            await _pushGovernedChargeAbnormalityMutation(
              local: record,
              remote: null,
              operation: ChargeAbnormalityMutationOperation.create,
            );
            _checkRunCurrent();
          }
          continue;
        }

        if (!sameChargeAbnormalityIdentity(record, remote)) {
          await _recordPushConflict(
            entityType: 'charge_abnormality',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          _checkRunCurrent();
          lastFailureCount++;
          continue;
        }

        if (record.isDeleted) {
          if (remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            convergedRecords.add(record);
            lastSuccessCount++;
            continue;
          }

          await _pushGovernedChargeAbnormalityMutation(
            local: record,
            remote: remote,
            operation: ChargeAbnormalityMutationOperation.softDelete,
          );
          _checkRunCurrent();
          continue;
        }

        if (remote.isDeleted) {
          try {
            final result = await _abnormalityRepo
                .applyTombstoneFromAbnormalityRemote(remote);
            _checkRunCurrent();
            if (await _guardedPushAwait(
              () async => _retainHoldForPreservedLocalTombstone(
                result: result,
                entityType: 'charge_abnormality',
                record: record,
                entityLabel: 'charge abnormality',
              ),
            )) {
              continue;
            }
            await _resolveRecheckedPermanentRejectionsForRecords(
              entityType: 'charge_abnormality',
              records: <ChargeAbnormality>[record],
              evidence:
                  'The canonical remote charge-abnormality tombstone was adopted locally.',
            );
            _checkRunCurrent();
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for charge abnormality ${record.id}',
            );
          } catch (e, stackTrace) {
            rethrowIfSyncRunMustAbort(e);
            _checkRunCurrent();
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
          final adopted = await _abnormalityRepo
              .applyAbnormalityServerReadbackIfUnchanged(
                remote,
                expectedLocal: snapshot,
                expectedLocalSynced: record.isSynced,
              );
          _checkRunCurrent();
          if (!adopted) {
            lastFailureCount++;
            _recordPushFailureDetail(
              entityType: 'charge_abnormality',
              entityId: _syncEntityId(record),
              error:
                  'Newer local abnormality work was preserved while adopting the exact server record.',
            );
            continue;
          }
          await _resolveRecheckedPermanentRejectionsForRecords(
            entityType: 'charge_abnormality',
            records: <ChargeAbnormality>[record],
            evidence:
                'Exact governed charge-abnormality state was read from the server and adopted locally.',
          );
          _checkRunCurrent();
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
          _checkRunCurrent();
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
        _checkRunCurrent();
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (snapshotsToMark.isNotEmpty) {
        await _abnormalityRepo.markAbnormalitiesSyncedIfUnchanged(
          snapshotsToMark,
        );
        _checkRunCurrent();
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'charge_abnormality',
          records: convergedRecords,
          evidence:
              'The remote charge-abnormality create or exact absence readback completed and the local snapshot was reconciled.',
        );
        _checkRunCurrent();
      }
    }
  }

  Future<void> _pushGovernedChargeAbnormalityMutation({
    required ChargeAbnormality local,
    required ChargeAbnormality? remote,
    required ChargeAbnormalityMutationOperation operation,
  }) async {
    final firestoreId = local.firestoreId!;
    final isCreate = operation == ChargeAbnormalityMutationOperation.create;
    if (!isCreate && (remote == null || local.version != remote.version + 1)) {
      await _recordPushConflict(
        entityType: 'charge_abnormality',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote?.toAuditMap() ?? const {},
      );
      _checkRunCurrent();
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
    final rawReason = operation == ChargeAbnormalityMutationOperation.softDelete
        ? local.deleteReason ?? 'Deleted charge abnormality'
        : 'Synchronised privileged charge-abnormality update';

    try {
      ChargeAbnormalityMutationResult? result;
      await _retry(
        () async {
          if (isCreate) {
            result = await _abnormalityCommands.create(
              abnormality: local,
              requestId: requestId,
            );
            _checkRunCurrent();
            return;
          }
          if (operation == ChargeAbnormalityMutationOperation.softDelete) {
            result = await _abnormalityCommands.softDelete(
              abnormality: local,
              expectedVersion: remote!.version,
              reason: rawReason,
              requestId: requestId,
            );
            _checkRunCurrent();
            return;
          }
          result = await _abnormalityCommands.update(
            abnormality: local,
            expectedVersion: remote!.version,
            reason: rawReason,
            requestId: requestId,
          );
          _checkRunCurrent();
        },
        shouldRetry: (error) {
          return error is! ChargeAbnormalityMutationException ||
              !error.isDurableRejection;
        },
      );
      _checkRunCurrent();
      final accepted = result;
      if (accepted == null) {
        throw const ChargeAbnormalityMutationException(
          code: 'internal',
          message: 'The governed abnormality mutation returned no result.',
          reasonCode: 'abnormality-response-missing',
        );
      }
      final adopted = await _abnormalityRepo
          .applyAbnormalityServerReadbackIfUnchanged(
            accepted.abnormality,
            expectedLocal: snapshot,
            expectedLocalSynced: local.isSynced,
          );
      _checkRunCurrent();
      if (!adopted) {
        throw StateError(
          'The governed abnormality mutation was accepted, but newer local '
          'work was preserved for reconciliation.',
        );
      }
      await _resolveRecheckedPermanentRejectionsForRecords(
        entityType: 'charge_abnormality',
        records: <ChargeAbnormality>[local],
        evidence:
            'The governed charge-abnormality callable returned an accepted server receipt that was adopted locally.',
      );
      _checkRunCurrent();
      lastSuccessCount++;
    } catch (error, stackTrace) {
      rethrowIfSyncRunMustAbort(error);
      _checkRunCurrent();
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
    return sameChargeAbnormalitySyncContent(local, remote);
  }
}
