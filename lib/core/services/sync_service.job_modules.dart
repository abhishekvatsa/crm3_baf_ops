part of 'sync_service.dart';

extension _SyncServiceJobModules on SyncService {
  Future<void> _syncJobModules() async {
    final unsynced = await _jobModuleRepo.getUnsyncedModules();
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
        entityType: 'job_module',
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

      final remoteList = await _firestoreJobModule.getModulesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobModuleInstance>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_module',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for job module ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for job module ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'job module ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote != null && remote.isDeleted) {
            if (jobModuleClientSnapshotsEquivalentForSync(record, remote)) {
              // Lost-response replay of the same governed tombstone. The
              // canonical remote client payload is already identical.
              skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
              lastSuccessCount++;
              continue;
            }

            // A different authoritative remote tombstone already won. Preserve
            // the local deletion intent in conflict audit before rebasing to
            // the remote canonical tombstone; never mark divergent local
            // provenance synchronized as though it matched.
            await _recordPushConflict(
              entityType: 'planned_job_module',
              entityId: record.firestoreId!,
              localSnapshot: record.toAuditMap(),
              remoteSnapshot: remote.toAuditMap(),
            );
            final result = await _jobModuleRepo.applyTombstoneFromRemote(
              remote,
            );
            if (result.outcome ==
                RemoteTombstoneApplyOutcome.localDirtyPreserved) {
              lastFailureCount++;
              await _recordJobModulePopulationFailure(
                record: record,
                error: const RuntimeJobModulePopulationException(
                  code: 'failed-precondition',
                  message:
                      'A different remote tombstone exists while fresher local deletion evidence remains unsynchronized.',
                  reasonCode: 'remote-tombstone-divergence',
                ),
              );
            } else {
              lastSuccessCount++;
            }
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _jobModuleRepo.applyTombstoneFromRemote(remote);
            lastSuccessCount++;
            debugPrint(
              '📥 Applied remote tombstone for job module ${record.id}',
            );
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for job module ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'planned_job_module',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local job module ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        if (remote != null) {
          final replayed = await _tryPushDecomposedJobModule(record, remote);
          if (replayed) {
            lastSuccessCount++;
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            debugPrint(
              '🪜 Replayed collapsed job-module submit→accept lifecycle: '
              '${record.firestoreId} (${_shortText(record.moduleTitle)})',
            );
            continue;
          }

          // If a first replay step committed but the second did not, the remote
          // may now be at `submitted`. Falling through to the normal push lets
          // the existing single-record diagnostics either complete the now
          // single-hop accepted update or surface the remaining rejection.
        }

        recordsToPush.add(record);
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(
            () async {
              await _firestoreJobModule.batchUpsertModules(recordsToPush);
            },
            shouldRetry:
                (error) =>
                    error is! RuntimeJobModulePopulationException ||
                    error.shouldRetryImmediately,
          );

          lastSuccessCount += recordsToPush.length;
          snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Job module batch sync failed; splitting batch for diagnostics: $e',
          );
          debugPrintStack(stackTrace: stackTrace);

          for (final record in recordsToPush) {
            try {
              await _retry(
                () async {
                  await _firestoreJobModule.batchUpsertModules([record]);
                },
                shouldRetry:
                    (error) =>
                        error is! RuntimeJobModulePopulationException ||
                        error.shouldRetryImmediately,
              );

              lastSuccessCount++;
              snapshotsToMark.add(_syncPushSnapshot(record));
              debugPrint(
                '✅ Job module synced after batch split: '
                '${record.firestoreId ?? record.id.toString()} '
                '(${_shortText(record.moduleTitle)})',
              );
            } catch (singleError, singleStackTrace) {
              final remote =
                  record.firestoreId == null
                      ? null
                      : remoteMap[record.firestoreId];

              if (_shouldRebaseRejectedTerminalJobModule(record, remote)) {
                await _recordPushConflict(
                  entityType: 'planned_job_module',
                  entityId: record.firestoreId!,
                  localSnapshot: record.toMap(),
                  remoteSnapshot: remote!.toMap(),
                );

                await _jobModuleRepo.forceRebaseModuleFromRemote(
                  remote,
                  reason:
                      'Rules rejected a dirty terminal-state module push. '
                      'The local snapshot was preserved in audit before rebasing.',
                );

                lastSuccessCount++;
                debugPrint(
                  '🛡️ Rebased rejected terminal job module from remote: '
                  '${record.firestoreId} (${_shortText(record.moduleTitle)})',
                );
                continue;
              }

              lastFailureCount++;
              if (singleError is RuntimeJobModulePopulationException) {
                await _recordJobModulePopulationFailure(
                  record: record,
                  error: singleError,
                );
              } else {
                _recordPushFailureDetail(
                  entityType: 'job_module',
                  entityId: _syncEntityId(record),
                  firestoreId: _syncFirestoreId(record),
                  error: singleError,
                );
              }
              debugPrint(
                '❌ Job module sync rejected after single-record retry:\n'
                '${_describeJobModuleForSync(record, remote)}\n'
                'Error: $singleError',
              );
              debugPrintStack(stackTrace: singleStackTrace);
            }
          }
        }
      }

      if (snapshotsToMark.isNotEmpty) {
        await _jobModuleRepo.markModulesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }

  bool _shouldRebaseRejectedTerminalJobModule(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null || local.firestoreId == null) return false;
    if (local.firestoreId != remote.firestoreId) return false;
    if (local.isDeleted || remote.isDeleted) return false;
    if (local.status != remote.status) return false;

    final isTerminal =
        local.status == JobModuleStatus.submitted ||
        local.status == JobModuleStatus.accepted ||
        local.status == JobModuleStatus.notApplicable;
    if (!isTerminal) return false;

    if (_jobModulePinnedFieldDiff(local, remote) != 'none') return false;

    // Once a module is in a terminal state on the server, Firestore rules
    // correctly refuse "submitted -> submitted" edits. A dirty local copy with
    // stale reopen/submission metadata can therefore never be pushed. Preserve
    // the local snapshot in audit and rebase to the server's canonical module.
    return _jobModuleLifecycleDiff(local, remote) != 'none' ||
        local.responsesJson != remote.responsesJson ||
        local.actionsJson != remote.actionsJson ||
        local.pendingIssue != remote.pendingIssue ||
        local.requiresFollowUp != remote.requiresFollowUp ||
        local.version != remote.version;
  }

  String _describeJobModuleForSync(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    String currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    } catch (_) {
      currentUid = 'firebase-auth-unavailable';
    }
    final localActionRead = local.actionsReadResult;
    final remoteActionRead = remote?.actionsReadResult;
    final buffer =
        StringBuffer()
          ..writeln('  currentAuthUid: $currentUid')
          ..writeln('  firestoreId: ${local.firestoreId ?? 'null'}')
          ..writeln('  localId: ${local.id}')
          ..writeln('  title: ${_shortText(local.moduleTitle, max: 120)}')
          ..writeln(
            '  local status/discipline/version/isSynced/isDeleted: '
            '${local.status.name}/${local.discipline.name}/${local.version}/'
            '${local.isSynced}/${local.isDeleted}',
          )
          ..writeln(
            '  remote status/discipline/version/isDeleted: '
            '${remote?.status.name ?? 'missing'}/'
            '${remote?.discipline.name ?? 'missing'}/'
            '${remote?.version.toString() ?? 'missing'}/'
            '${remote?.isDeleted.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local createdBy/updatedBy/submittedBy/acceptedBy/reopenedBy/notApplicableBy/deletedBy: '
            '${_uid(local.createdByUid)}/${_uid(local.updatedByUid)}/'
            '${_uid(local.submittedByUid)}/${_uid(local.acceptedByUid)}/'
            '${_uid(local.reopenedByUid)}/${_uid(local.notApplicableByUid)}/'
            '${_uid(local.deletedByUid)}',
          )
          ..writeln(
            '  remote createdBy/updatedBy/submittedBy/acceptedBy/reopenedBy/notApplicableBy/deletedBy: '
            '${_uid(remote?.createdByUid)}/${_uid(remote?.updatedByUid)}/'
            '${_uid(remote?.submittedByUid)}/${_uid(remote?.acceptedByUid)}/'
            '${_uid(remote?.reopenedByUid)}/${_uid(remote?.notApplicableByUid)}/'
            '${_uid(remote?.deletedByUid)}',
          )
          ..writeln(
            '  local assetType/assetNumber: '
            '${local.assetType.name}/${local.assetNumber}',
          )
          ..writeln(
            '  remote assetType/assetNumber: '
            '${remote?.assetType.name ?? 'missing'}/'
            '${remote?.assetNumber.toString() ?? 'missing'}',
          )
          ..writeln(
            '  local createdAt/updatedAt: '
            '${_date(local.createdAt)}/${_date(local.updatedAt)}',
          )
          ..writeln(
            '  remote createdAt/updatedAt: '
            '${_date(remote?.createdAt)}/${_date(remote?.updatedAt)}',
          )
          ..writeln(
            '  local response/action counts: '
            '${local.responses.length}/'
            '${localActionRead.isValid ? localActionRead.entries.length : 'invalid'}',
          )
          ..writeln(
            '  remote response/action counts: '
            '${remote?.responses.length.toString() ?? 'missing'}/'
            '${remoteActionRead == null
                ? 'missing'
                : remoteActionRead.isValid
                ? remoteActionRead.entries.length
                : 'invalid'}',
          )
          ..writeln(
            '  payload comparison: ${_jobModulePayloadDiff(local, remote)}',
          )
          ..writeln(
            '  pinned-field comparison: ${_jobModulePinnedFieldDiff(local, remote)}',
          )
          ..writeln(
            '  lifecycle-field comparison: ${_jobModuleLifecycleDiff(local, remote)}',
          );

    return buffer.toString().trimRight();
  }

  String _jobModulePinnedFieldDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.createdByUid != remote.createdByUid) diffs.add('createdByUid');
    if (!_sameInstant(local.createdAt, remote.createdAt)) {
      diffs.add('createdAt');
    }
    if (local.moduleSnapshotJson != remote.moduleSnapshotJson) {
      diffs.add('moduleSnapshotJson');
    }
    if (local.fieldDefinitionsJson != remote.fieldDefinitionsJson) {
      diffs.add('fieldDefinitionsJson');
    }
    if (local.assetType != remote.assetType) diffs.add('assetType');
    if (local.assetNumber != remote.assetNumber) diffs.add('assetNumber');
    if (local.discipline != remote.discipline) diffs.add('discipline');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _jobModulePayloadDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.responsesJson != remote.responsesJson) diffs.add('responsesJson');
    if (local.actionsJson != remote.actionsJson) diffs.add('actionsJson');
    if (local.draftNote != remote.draftNote) diffs.add('draftNote');
    if (local.pendingIssue != remote.pendingIssue) diffs.add('pendingIssue');
    if (local.requiresFollowUp != remote.requiresFollowUp) {
      diffs.add('requiresFollowUp');
    }

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  String _jobModuleLifecycleDiff(
    JobModuleInstance local,
    JobModuleInstance? remote,
  ) {
    if (remote == null) return 'remote missing; create rules will apply';

    final diffs = <String>[];
    if (local.status != remote.status) diffs.add('status');
    if (local.isDeleted != remote.isDeleted) diffs.add('isDeleted');
    if (local.submittedByUid != remote.submittedByUid) {
      diffs.add('submittedByUid');
    }
    if (local.submittedByName != remote.submittedByName) {
      diffs.add('submittedByName');
    }
    if (!_sameInstant(local.submittedAt, remote.submittedAt)) {
      diffs.add('submittedAt');
    }
    if (local.submissionNote != remote.submissionNote) {
      diffs.add('submissionNote');
    }
    if (local.acceptedByUid != remote.acceptedByUid) diffs.add('acceptedByUid');
    if (local.acceptedByName != remote.acceptedByName) {
      diffs.add('acceptedByName');
    }
    if (!_sameInstant(local.acceptedAt, remote.acceptedAt)) {
      diffs.add('acceptedAt');
    }
    if (local.acceptanceNote != remote.acceptanceNote) {
      diffs.add('acceptanceNote');
    }
    if (local.reopenedByUid != remote.reopenedByUid) diffs.add('reopenedByUid');
    if (local.reopenedByName != remote.reopenedByName) {
      diffs.add('reopenedByName');
    }
    if (!_sameInstant(local.reopenedAt, remote.reopenedAt)) {
      diffs.add('reopenedAt');
    }
    if (local.reopenReason != remote.reopenReason) diffs.add('reopenReason');
    if (local.notApplicableByUid != remote.notApplicableByUid) {
      diffs.add('notApplicableByUid');
    }
    if (local.notApplicableByName != remote.notApplicableByName) {
      diffs.add('notApplicableByName');
    }
    if (!_sameInstant(local.notApplicableAt, remote.notApplicableAt)) {
      diffs.add('notApplicableAt');
    }
    if (local.notApplicableReason != remote.notApplicableReason) {
      diffs.add('notApplicableReason');
    }
    if (local.deletedByUid != remote.deletedByUid) diffs.add('deletedByUid');
    if (local.deletedByName != remote.deletedByName) diffs.add('deletedByName');
    if (!_sameInstant(local.deletedAt, remote.deletedAt)) {
      diffs.add('deletedAt');
    }
    if (local.deleteReason != remote.deleteReason) diffs.add('deleteReason');

    return diffs.isEmpty ? 'none' : diffs.join(', ');
  }

  List<_JobModuleReplayStep> _jobModuleLifecycleReplayPlan(
    JobModuleInstance local,
    JobModuleInstance remote,
  ) {
    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null || firestoreId != _cleanText(remote.firestoreId)) {
      return const [];
    }
    if (local.isDeleted || remote.isDeleted) return const [];
    if (local.status != JobModuleStatus.accepted) return const [];
    if (!_isOpenJobModuleStatus(remote.status)) return const [];

    // This repair is deliberately limited to the proven offline multi-hop
    // collapse. A normal one-hop update remains on the existing batch path.
    if (local.version <= remote.version + 1) return const [];

    final currentUid = _cleanText(FirebaseAuth.instance.currentUser?.uid);
    final submittedByUid = _cleanText(local.submittedByUid);
    final acceptedByUid = _cleanText(local.acceptedByUid);
    if (currentUid == null || submittedByUid == null || acceptedByUid == null) {
      return const [];
    }

    // Firestore rules bind submittedByUid and acceptedByUid to request.auth.uid.
    // Therefore the first safe implementation only replays same-auth collapses.
    // Cross-actor offline submit→accept remains unsupported and should fail via
    // the normal diagnostics path rather than being replayed incorrectly.
    if (submittedByUid != currentUid || acceptedByUid != currentUid) {
      return const [];
    }

    if (local.submittedAt == null || local.acceptedAt == null) return const [];

    if (_jobModulePinnedFieldDiff(local, remote) != 'none') return const [];

    return const [_JobModuleReplayStep.submit, _JobModuleReplayStep.accept];
  }

  Future<bool> _tryPushDecomposedJobModule(
    JobModuleInstance local,
    JobModuleInstance remote,
  ) async {
    final plan = _jobModuleLifecycleReplayPlan(local, remote);
    if (plan.isEmpty) return false;

    final firestoreId = _cleanText(local.firestoreId);
    if (firestoreId == null) return false;

    var stepVersion = remote.version;
    try {
      for (final step in plan) {
        final Map<String, dynamic> stepData;
        if (step == _JobModuleReplayStep.submit) {
          stepVersion += 1;
          stepData = _jobModuleSubmitReplayStepData(local, stepVersion);
        } else {
          stepData = _jobModuleAcceptReplayStepData(local);
          stepVersion = stepData['version'] as int;
        }

        await _retry(() async {
          await _firestoreJobModule.applyRemoteLifecycleReplayStepForSync(
            firestoreId,
            stepData,
          );
        });
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Decomposed job-module lifecycle replay did not fully complete for '
        '$firestoreId (${_shortText(local.moduleTitle)}): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Map<String, dynamic> _jobModuleSubmitReplayStepData(
    JobModuleInstance local,
    int version,
  ) {
    final full = local.toMap();
    return <String, dynamic>{
      'status': JobModuleStatus.submitted.name,
      'isOpenForWork': false,
      'responsesJson': full['responsesJson'],
      'actionsJson': full['actionsJson'],
      'draftNote': full['draftNote'],
      'pendingIssue': full['pendingIssue'],
      'requiresFollowUp': full['requiresFollowUp'],
      'submittedByUid': full['submittedByUid'],
      'submittedByName': full['submittedByName'],
      'submittedAt': full['submittedAt'],
      'submissionNote': full['submissionNote'],
      'updatedAt': full['submittedAt'] ?? full['updatedAt'],
      'updatedByUid': full['submittedByUid'],
      'updatedByName': full['submittedByName'],
      'version': version,
      'metadataJson': full['metadataJson'],
    };
  }

  Map<String, dynamic> _jobModuleAcceptReplayStepData(JobModuleInstance local) {
    final full = local.toMap();
    return <String, dynamic>{
      'status': JobModuleStatus.accepted.name,
      'isOpenForWork': false,
      'acceptedByUid': full['acceptedByUid'],
      'acceptedByName': full['acceptedByName'],
      'acceptedAt': full['acceptedAt'],
      'acceptanceNote': full['acceptanceNote'],
      'updatedAt': full['acceptedAt'] ?? full['updatedAt'],
      'updatedByUid': full['acceptedByUid'],
      'updatedByName': full['acceptedByName'],
      'version': full['version'],
      'metadataJson': full['metadataJson'],
    };
  }

  bool _isOpenJobModuleStatus(JobModuleStatus status) {
    return status == JobModuleStatus.notStarted ||
        status == JobModuleStatus.draftSaved ||
        status == JobModuleStatus.inProgress ||
        status == JobModuleStatus.reopened;
  }
}

enum _JobModuleReplayStep { submit, accept }
