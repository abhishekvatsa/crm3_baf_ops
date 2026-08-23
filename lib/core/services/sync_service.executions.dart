part of 'sync_service.dart';

extension _SyncServiceExecutions on SyncService {
  Future<void> _syncExecutions({bool skipCompletedClosures = false}) async {
    final unsynced = await _plannedRepo.getUnsyncedExecutions();
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
        entityType: 'job_execution',
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

      final remoteList = await _firestorePlanned.getExecutionsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobExecution>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];
      final convergedRecords = <JobExecution>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_execution',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for execution ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for execution ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'execution ${record.id}');

        final remote = remoteMap[record.firestoreId];
        final localResponseRead = record.responsesReadResult;
        final localActionRead = record.actionsReadResult;
        if (!localResponseRead.isValid || !localActionRead.isValid) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_execution',
            entityId: _syncEntityId(record),
            error: 'Saved responses or actions need repair before sync.',
          );
          continue;
        }
        if (remote != null &&
            (!remote.responsesReadResult.isValid ||
                !remote.actionsReadResult.isValid)) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_execution',
            entityId: _syncEntityId(record),
            error:
                'Remote responses or actions need repair before they can be overwritten.',
          );
          continue;
        }

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

          if (_shouldRebaseRejectedExecutionTombstone(record, remote)) {
            await _recordPushConflict(
              entityType: 'job_execution',
              entityId: record.firestoreId!,
              localSnapshot: record.toMap(),
              remoteSnapshot: remote!.toMap(),
            );

            await _plannedRepo.forceRebaseExecutionFromRemote(
              remote,
              reason:
                  'Rules reject local job-execution tombstones. '
                  'The local snapshot was preserved in audit before rebasing.',
            );

            await _resolveRecheckedPermanentRejectionsForRecords(
              entityType: 'job_execution',
              records: <JobExecution>[record],
              evidence:
                  'The canonical remote execution was adopted after preserving the rejected local tombstone in audit.',
            );

            lastSuccessCount++;
            debugPrint(
              '🛡️ Rebased local job execution tombstone from remote: '
              '${record.firestoreId} (${_shortText(record.templateName ?? record.templateFirestoreId)})',
            );
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _plannedRepo.applyTombstoneFromExecutionRemote(remote);
            await _resolveRecheckedPermanentRejectionsForRecords(
              entityType: 'job_execution',
              records: <JobExecution>[record],
              evidence:
                  'The canonical remote job-execution tombstone was adopted locally.',
            );
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for execution ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for execution ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (record.isCompleted) {
          if (skipCompletedClosures) {
            continue;
          }

          final serverCompleted = await _syncCompletedExecutionThroughServer(
            record,
            remote,
          );
          if (serverCompleted) {
            lastSuccessCount++;
          }
          // Never fall back to direct Firestore batch upsert for completed
          // executions. Firestore rules now deny client completion so the
          // Cloud Function remains the single completion authority.
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'execution',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local execution ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestorePlanned.batchUpsertExecutions(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Execution batch sync failed; splitting batch for diagnostics: $e',
          );
          debugPrintStack(stackTrace: stackTrace);

          for (final record in recordsToPush) {
            try {
              await _retry(() async {
                await _firestorePlanned.batchUpsertExecutions([record]);
              });

              lastSuccessCount++;
              skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
              convergedRecords.add(record);
              debugPrint(
                '✅ Execution synced after batch split: '
                '${record.firestoreId ?? record.id.toString()} '
                '(${_shortText(record.templateName ?? record.templateFirestoreId)})',
              );
            } catch (singleError, singleStackTrace) {
              final remote =
                  record.firestoreId == null
                      ? null
                      : remoteMap[record.firestoreId];

              if (_shouldRebaseRejectedExecutionTombstone(record, remote)) {
                await _recordPushConflict(
                  entityType: 'job_execution',
                  entityId: record.firestoreId!,
                  localSnapshot: record.toMap(),
                  remoteSnapshot: remote!.toMap(),
                );

                await _plannedRepo.forceRebaseExecutionFromRemote(
                  remote,
                  reason:
                      'Rules rejected a dirty local job-execution tombstone. '
                      'The local snapshot was preserved in audit before rebasing.',
                );

                await _resolveRecheckedPermanentRejectionsForRecords(
                  entityType: 'job_execution',
                  records: <JobExecution>[record],
                  evidence:
                      'The canonical remote execution was adopted after preserving the rejected local tombstone in audit.',
                );

                lastSuccessCount++;
                debugPrint(
                  '🛡️ Rebased rejected job execution tombstone from remote: '
                  '${record.firestoreId} (${_shortText(record.templateName ?? record.templateFirestoreId)})',
                );
                continue;
              }

              lastFailureCount++;
              _recordPushFailureDetail(
                entityType: 'job_execution',
                entityId: _syncEntityId(record),
                error: singleError,
              );
              debugPrint(
                '❌ Execution sync rejected after single-record retry:\n'
                '${_describeExecutionForSync(record, remote)}\n'
                'Error: $singleError',
              );
              debugPrintStack(stackTrace: singleStackTrace);
            }
          }
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
        convergedRecords.addAll(recordsToPush);
      }

      if (snapshotsToMark.isNotEmpty) {
        await _plannedRepo.markExecutionsSyncedIfUnchanged(snapshotsToMark);
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'job_execution',
          records: convergedRecords,
          evidence:
              'The remote job-execution write or exact readback completed and the local snapshot was reconciled.',
        );
      }
    }
  }

  Future<void> _syncCompletedExecutionClosures() async {
    final unsynced = await _plannedRepo.getUnsyncedExecutions();
    final completed =
        unsynced
            .where(
              (execution) =>
                  execution.isCompleted &&
                  !execution.isDeleted &&
                  execution.firestoreId != null &&
                  execution.firestoreId!.trim().isNotEmpty,
            )
            .toList();

    if (completed.isEmpty) {
      return;
    }

    for (var i = 0; i < completed.length; i += 100) {
      final batchRecords = completed.sublist(
        i,
        i + 100 > completed.length ? completed.length : i + 100,
      );
      final activeBatchRecords = await _recordsEligibleForAutomaticPush(
        entityType: 'job_execution',
        records: batchRecords,
      );
      if (activeBatchRecords.isEmpty) {
        continue;
      }

      final firestoreIds =
          activeBatchRecords
              .map((execution) => execution.firestoreId)
              .whereType<String>()
              .toList();

      final remoteList = await _firestorePlanned.getExecutionsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {
        for (final remote in remoteList) remote.firestoreId: remote,
      };

      for (final record in activeBatchRecords) {
        final accepted = await _syncCompletedExecutionThroughServer(
          record,
          remoteMap[record.firestoreId],
        );
        if (accepted) {
          lastSuccessCount++;
        }
      }
    }
  }

  Future<bool> _syncCompletedExecutionThroughServer(
    JobExecution local,
    JobExecution? remote,
  ) async {
    final firestoreId = local.firestoreId;
    if (firestoreId == null || firestoreId.trim().isEmpty) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: 'local:${local.id}',
        error:
            'Completed local execution has no firestoreId; cannot route through server closure function.',
      );
      return false;
    }

    if (remote == null) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Remote execution is missing; server-side completion cannot be validated.',
      );
      return false;
    }

    if (remote.isDeleted) {
      try {
        await _plannedRepo.applyTombstoneFromExecutionRemote(remote);
        await _resolveRecheckedPermanentRejectionsForRecords(
          entityType: 'job_execution',
          records: <JobExecution>[local],
          evidence:
              'The canonical remote completed-execution tombstone was adopted locally.',
        );
        debugPrint(
          '📥 Applied remote tombstone for completed execution ${local.id}',
        );
        return true;
      } catch (error, stackTrace) {
        lastFailureCount++;
        _recordPushFailureDetail(
          entityType: 'job_execution',
          entityId: _syncEntityId(local),
          firestoreId: firestoreId,
          error: error,
        );
        debugPrint('❌ Failed applying remote execution tombstone: $error');
        debugPrintStack(stackTrace: stackTrace);
        return false;
      }
    }

    if (remote.isCompleted) {
      await _recordPushConflict(
        entityType: 'execution',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote.toAuditMap(),
      );
      await _plannedRepo.forceRebaseExecutionFromRemote(
        remote,
        reason:
            'Remote job execution is already server-completed. '
            'Local dirty completion snapshot was preserved in audit before rebasing.',
      );
      await _resolveRecheckedPermanentRejectionsForRecords(
        entityType: 'job_execution',
        records: <JobExecution>[local],
        evidence:
            'The canonical server-completed execution was read and adopted locally after preserving conflict evidence.',
      );
      debugPrint(
        '🛡️ Rebased local completed execution from canonical server completion: '
        '$firestoreId',
      );
      return true;
    }

    if (_isRemoteNewer(local, remote)) {
      await _recordPushConflict(
        entityType: 'execution',
        entityId: firestoreId,
        localSnapshot: local.toAuditMap(),
        remoteSnapshot: remote.toAuditMap(),
      );
      lastFailureCount++;
      return false;
    }

    final completedByUid = _cleanText(local.completedByUid);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (completedByUid == null || currentUid != completedByUid) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Server-side completion requires the signed-in user to match completedByUid.',
      );
      return false;
    }

    late final List<JobModuleInstance> localModules;
    try {
      localModules = await _jobModuleRepo.getModulesForJob(
        jobExecutionFirestoreId: firestoreId,
        jobExecutionLocalId: local.id,
      );
    } catch (error, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Cannot server-complete job while local module identity is '
            'ambiguous: $error',
      );
      debugPrint(
        '❌ Server-side planned-job completion preflight could not resolve '
        'the canonical local module set for $firestoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }

    final unsyncedModules =
        localModules.where((module) => !module.isSynced).toList();
    if (unsyncedModules.isNotEmpty) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: _syncEntityId(local),
        firestoreId: firestoreId,
        error:
            'Cannot server-complete job before ${unsyncedModules.length} dirty module(s) are synced.',
      );
      return false;
    }

    try {
      final completed = await _serverCompletion.completeExecution(
        executionFirestoreId: firestoreId,
        remarks: local.remarks,
        teamsInvolved: local.teamsInvolved,
        responses: local.responses,
        actions: local.actions,
        expectedCompletionVersion: local.version,
      );

      await _plannedRepo.forceRebaseExecutionFromRemote(
        completed,
        reason:
            'Local completed execution was accepted by server-side closure function.',
      );
      await _resolveRecheckedPermanentRejectionsForRecords(
        entityType: 'job_execution',
        records: <JobExecution>[local],
        evidence:
            'The server completion callable returned an authoritative execution receipt that was adopted locally.',
      );

      debugPrint(
        '✅ Server-side planned-job completion accepted during sync: '
        '$firestoreId',
      );
      return true;
    } catch (error, stackTrace) {
      lastFailureCount++;
      _recordPushFailureDetail(
        entityType: 'job_execution',
        entityId: firestoreId,
        error: error,
      );
      debugPrint(
        '❌ Server-side planned-job completion failed during sync for '
        '$firestoreId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  bool _shouldRebaseRejectedExecutionTombstone(
    JobExecution local,
    JobExecution? remote,
  ) {
    if (remote == null) {
      return false;
    }
    if (!local.isDeleted || remote.isDeleted) {
      return false;
    }

    // Identity fields pinned by Firestore rules must match exactly.
    if (local.templateFirestoreId != remote.templateFirestoreId) {
      return false;
    }
    if (local.assetType != remote.assetType) {
      return false;
    }
    if (local.assetNumber != remote.assetNumber) {
      return false;
    }

    // Do not silently discard actual dossier content. These tombstones are
    // safe to rebase only when no local checklist responses/actions are waiting
    // to be recovered. If this guard fails, diagnostics stay loud.
    final localResponseRead = local.responsesReadResult;
    if (!localResponseRead.isValid || localResponseRead.entries.isNotEmpty) {
      return false;
    }
    final localActionRead = local.actionsReadResult;
    if (!localActionRead.isValid || localActionRead.entries.isNotEmpty) {
      return false;
    }

    // Completion state must already agree with remote. The timestamp/version may
    // differ due to historical double-completion/local tombstone drift, but a
    // true local completion over an open remote job must never be rebased away.
    if (local.isCompleted != remote.isCompleted) {
      return false;
    }
    if (_cleanText(local.completedByUid) != _cleanText(remote.completedByUid)) {
      return false;
    }

    // Preserve potentially meaningful local business fields by refusing the
    // automatic rebase when they differ. The diagnostic block will then show the
    // exact rejected record for manual handling.
    if (_cleanText(local.remarks) != _cleanText(remote.remarks)) {
      return false;
    }
    if (!_sameStringList(local.teamsInvolved, remote.teamsInvolved)) {
      return false;
    }
    if (local.chargeNoAtEvent != remote.chargeNoAtEvent) {
      return false;
    }
    if (_cleanText(local.metadataJson) != _cleanText(remote.metadataJson)) {
      return false;
    }

    return true;
  }

  String _describeExecutionForSync(JobExecution local, JobExecution? remote) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    final localActionRead = local.actionsReadResult;
    final remoteActionRead = remote?.actionsReadResult;
    final localResponseRead = local.responsesReadResult;
    final remoteResponseRead = remote?.responsesReadResult;
    final buffer =
        StringBuffer()
          ..writeln('  currentAuthUid: $currentUid')
          ..writeln('  firestoreId: ${local.firestoreId ?? 'null'}')
          ..writeln('  localId: ${local.id}')
          ..writeln(
            '  template: ${_shortText(local.templateName ?? local.templateFirestoreId)}',
          )
          ..writeln(
            '  local asset/version/isCompleted/isDeleted/isSynced: '
            '${local.assetType.name}/${local.assetNumber}/${local.version}/'
            '${local.isCompleted}/${local.isDeleted}/${local.isSynced}',
          )
          ..writeln(
            '  remote asset/version/isCompleted/isDeleted: '
            '${remote?.assetType.name ?? 'missing'}/'
            '${remote?.assetNumber.toString() ?? 'missing'}/'
            '${remote?.version.toString() ?? 'missing'}/'
            '${remote?.isCompleted.toString() ?? 'missing'}/'
            '${remote?.isDeleted.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local completedBy/completedAt: '
            '${_uid(local.completedByUid)}/${_date(local.completedAt)}',
          )
          ..writeln(
            '  remote completedBy/completedAt: '
            '${_uid(remote?.completedByUid)}/${_date(remote?.completedAt)}',
          )
          ..writeln('  local updatedAt: ${_date(local.updatedAt)}')
          ..writeln('  remote updatedAt: ${_date(remote?.updatedAt)}')
          ..writeln(
            '  local response/action counts: '
            '${localResponseRead.isValid ? localResponseRead.entries.length : 'invalid'}/'
            '${localActionRead.isValid ? localActionRead.entries.length : 'invalid'}',
          )
          ..writeln(
            '  remote response/action counts: '
            '${remoteResponseRead == null
                ? 'missing'
                : remoteResponseRead.isValid
                ? remoteResponseRead.entries.length
                : 'invalid'}/'
            '${remoteActionRead == null
                ? 'missing'
                : remoteActionRead.isValid
                ? remoteActionRead.entries.length
                : 'invalid'}',
          )
          ..writeln(
            '  pinned-field comparison: ${_executionPinnedFieldDiff(local, remote)}',
          )
          ..writeln(
            '  completion-field comparison: ${_executionCompletionFieldDiff(local, remote)}',
          );

    return buffer.toString().trimRight();
  }

  String _executionPinnedFieldDiff(JobExecution local, JobExecution? remote) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.templateFirestoreId != remote.templateFirestoreId) {
      diffs.add('templateFirestoreId');
    }
    if (local.assetType != remote.assetType) diffs.add('assetType');
    if (local.assetNumber != remote.assetNumber) diffs.add('assetNumber');
    if (local.isDeleted != remote.isDeleted) diffs.add('isDeleted');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _executionCompletionFieldDiff(
    JobExecution local,
    JobExecution? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.isCompleted != remote.isCompleted) diffs.add('isCompleted');
    if (local.completedByUid != remote.completedByUid) {
      diffs.add('completedByUid');
    }
    if (local.completedByName != remote.completedByName) {
      diffs.add('completedByName');
    }
    if (!_sameInstant(local.completedAt, remote.completedAt)) {
      diffs.add('completedAt');
    }
    if (local.version != remote.version) diffs.add('version');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }
}
