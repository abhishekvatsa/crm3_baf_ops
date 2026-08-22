part of 'sync_service.dart';

extension _SyncServiceTicketsTemplates on SyncService {
  Future<void> _syncTickets() async {
    final unsynced = await _maintenanceRepo.getUnsyncedTickets();
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
        entityType: 'maintenance_ticket',
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

      final remoteList = await _firestoreMaintenance.getTicketsByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <MaintenanceRecord>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'maintenance_ticket',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for ticket ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for ticket ${record.id}');
          continue;
        }

        final evidenceError = _maintenanceEvidenceIntegrityError(record);
        if (evidenceError != null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'maintenance_ticket',
            entityId: record.firestoreId!,
            error: evidenceError,
          );
          debugPrint('Blocked ticket sync for ${record.id}: $evidenceError');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'ticket ${record.id}');

        final remote = remoteMap[record.firestoreId];

        if (record.isDeleted) {
          if (remote == null) {
            // The issue never crossed the governed creation boundary, so no
            // remote record exists to tombstone. Retain the local deletion and
            // stop retrying an impossible direct create.
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }
          if (remote.isDeleted) {
            skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
            lastSuccessCount++;
            continue;
          }

          recordsToPush.add(record);
          continue;
        }

        if (remote != null && remote.isDeleted) {
          try {
            await _maintenanceRepo.applyTombstoneFromMaintenanceRemote(remote);
            lastSuccessCount++;
            debugPrint('📥 Applied remote tombstone for ticket ${record.id}');
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for ticket ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote == null) {
          try {
            final expectedLocal = _syncPushSnapshot(record);
            final creation = await _pushMissingMaintenanceTicket(record);
            final adopted = await _maintenanceRepo
                .applyGovernedCreationReceiptForSync(
                  firestoreId: record.firestoreId!,
                  expectedLocal: expectedLocal,
                  serverCreateVersion: creation.receipt.aggregateVersion,
                  serverAppliedAt: creation.receipt.appliedAt,
                  hasPostCreateLifecycle: creation.hasPostCreateLifecycle,
                );
            if (!adopted) {
              debugPrint(
                'Governed ticket ${record.id} was created remotely, but the '
                'local row changed during submission and remains pending.',
              );
            }
            lastSuccessCount++;
          } catch (error, stackTrace) {
            lastFailureCount++;
            _recordPushFailureDetail(
              entityType: 'maintenance_ticket',
              entityId: record.firestoreId!,
              error: error,
            );
            debugPrint(
              'Governed ticket creation failed for ${record.id}: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        final replayed = await _tryPushDecomposedMaintenanceTicket(
          record,
          remote,
        );
        if (replayed) {
          skippedButSyncedSnapshots.add(_syncPushSnapshot(record));
          lastSuccessCount++;
          continue;
        }

        if (_isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'ticket',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local ticket ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      if (skippedButSyncedSnapshots.isNotEmpty) {
        await _maintenanceRepo.markTicketsSyncedIfUnchanged(
          skippedButSyncedSnapshots,
        );
      }

      for (
        var offset = 0;
        offset < recordsToPush.length;
        offset += maintenancePairedBatchMaximum
      ) {
        final chunk = recordsToPush.sublist(
          offset,
          offset + maintenancePairedBatchMaximum > recordsToPush.length
              ? recordsToPush.length
              : offset + maintenancePairedBatchMaximum,
        );
        try {
          await _retry(() async {
            await _firestoreMaintenance.batchUpsertTickets(chunk);
          });
        } catch (e, stackTrace) {
          lastFailureCount += chunk.length;
          _recordPushFailuresForBatch(
            entityType: 'maintenance_ticket',
            records: chunk,
            error: e,
          );
          debugPrint('❌ Ticket batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
          continue;
        }
        try {
          await _retry(
            () => _maintenanceRepo.markTicketsSyncedIfUnchanged(
              _syncPushSnapshots(chunk),
            ),
          );
          lastSuccessCount += chunk.length;
        } catch (e, stackTrace) {
          lastFailureCount += chunk.length;
          _recordPushFailuresForBatch(
            entityType: 'maintenance_ticket',
            records: chunk,
            error: e,
          );
          debugPrint(
            '❌ Ticket batch committed remotely but could not be marked '
            'locally: $e',
          );
          debugPrintStack(stackTrace: stackTrace);
          break;
        }
      }
    }
  }

  String? _maintenanceEvidenceIntegrityError(MaintenanceRecord record) {
    final actions = record.actionsReadResult;
    if (!actions.isValid) {
      return 'Saved action evidence needs repair before synchronization.';
    }
    final history = record.resolutionHistoryReadResult;
    if (!history.isValid) {
      return 'Saved resolution history needs repair before synchronization.';
    }
    return null;
  }

  Future<_MaintenanceCreationReplayResult> _pushMissingMaintenanceTicket(
    MaintenanceRecord local,
  ) async {
    final currentUid = _cleanMaintenanceText(
      FirebaseAuth.instance.currentUser?.uid,
    );
    if (currentUid == null ||
        !_canReplayMaintenanceCreateForCurrentUser(local, currentUid)) {
      throw StateError(
        'Only the original signed-in reporter may synchronize this issue.',
      );
    }
    final createVersion = _maintenanceCreateReplayVersion(local);
    final command = buildMaintenanceIssueCreateCommand(
      local,
      createVersion: createVersion,
    );
    WorkflowCommandReceipt? receipt;
    await _retry(() async {
      receipt = await _maintenanceCommands.execute(command);
    });
    final applied = receipt!;
    validateMaintenanceIssueCreateReceipt(
      command: command,
      receipt: applied,
      createVersion: createVersion,
    );

    if (local.isResolved) {
      final close = _maintenanceCloseReplayStepData(
        local,
        null,
        createVersion,
        applied.appliedAt,
      );
      await _retry(
        () => _applyMaintenanceLifecycleReplayStep(local.firestoreId!, close),
      );
      return (receipt: applied, hasPostCreateLifecycle: true);
    }
    if (_hasMaintenanceReopenEvidence(local)) {
      final close = _maintenanceCloseReplayStepData(
        local,
        null,
        createVersion,
        applied.appliedAt,
      );
      await _retry(
        () => _applyMaintenanceLifecycleReplayStep(local.firestoreId!, close),
      );
      final reopen = _maintenanceReopenReplayStepData(local, applied.appliedAt);
      await _retry(
        () => _applyMaintenanceLifecycleReplayStep(local.firestoreId!, reopen),
      );
      return (receipt: applied, hasPostCreateLifecycle: true);
    }
    return (receipt: applied, hasPostCreateLifecycle: false);
  }

  Future<bool> _tryPushDecomposedMaintenanceTicket(
    MaintenanceRecord local,
    MaintenanceRecord? remote,
  ) async {
    final plan = _maintenanceLifecycleReplayPlan(local, remote);
    if (plan.isEmpty) return false;

    try {
      var stepVersion =
          remote?.version ?? _maintenanceCreateReplayVersion(local);
      for (final step in plan) {
        final stepData = switch (step) {
          _MaintenanceReplayStep.close => _maintenanceCloseReplayStepData(
            local,
            remote,
            stepVersion,
          ),
          _MaintenanceReplayStep.reopen => _maintenanceReopenReplayStepData(
            local,
          ),
        };

        await _retry(
          () => _applyMaintenanceLifecycleReplayStep(
            local.firestoreId!,
            stepData,
          ),
        );

        stepVersion = stepData['version'] as int;
      }
      return true;
    } catch (error, stackTrace) {
      // If an early replay step committed but a later one did not, falling
      // through to the normal batch path allows the existing push diagnostics to
      // either complete the now single-hop transition or surface the remaining
      // rejection without losing local evidence.
      debugPrint(
        '⚠️ Maintenance lifecycle replay did not complete for ticket ${local.id}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _applyMaintenanceLifecycleReplayStep(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    try {
      await _firestoreMaintenance
          .applyRemoteMaintenanceLifecycleReplayStepForSync(
            firestoreId,
            stepData,
          );
    } catch (_) {
      final observed = await _firestoreMaintenance
          .readRemoteMaintenanceLifecycleReplayFieldsForSync(firestoreId);
      if (maintenanceLifecycleReplayOutcomeMatches(observed, stepData)) {
        debugPrint(
          'Maintenance lifecycle replay for $firestoreId was confirmed by '
          'readback after an uncertain write outcome.',
        );
        return;
      }
      rethrow;
    }
  }

  List<_MaintenanceReplayStep> _maintenanceLifecycleReplayPlan(
    MaintenanceRecord local,
    MaintenanceRecord? remote,
  ) {
    final firestoreId = _cleanMaintenanceText(local.firestoreId);
    if (firestoreId == null) return const [];
    if (remote != null &&
        firestoreId != _cleanMaintenanceText(remote.firestoreId)) {
      return const [];
    }
    if (local.isDeleted || (remote?.isDeleted ?? false)) return const [];

    final currentUid = _cleanMaintenanceText(
      FirebaseAuth.instance.currentUser?.uid,
    );
    if (currentUid == null) return const [];

    final closeEvidence = _maintenanceCloseEvidence(local);

    if (remote == null) return const [];

    if (_maintenancePinnedFieldDiff(local, remote) != 'none') return const [];

    if (remote.isResolved) {
      if (!local.isResolved &&
          _hasMaintenanceReopenEvidence(local) &&
          local.version > remote.version) {
        return const [_MaintenanceReplayStep.reopen];
      }
      return const [];
    }

    if (local.isResolved) {
      if (!maintenanceResolvedReplayCanRebase(
        local: local,
        remote: remote,
        currentUid: currentUid,
      )) {
        return const [];
      }
      return const [_MaintenanceReplayStep.close];
    }

    if (_hasMaintenanceReopenEvidence(local) &&
        local.version > remote.version + 1 &&
        _canReplayMaintenanceCloseForCurrentUser(closeEvidence, currentUid)) {
      return const [
        _MaintenanceReplayStep.close,
        _MaintenanceReplayStep.reopen,
      ];
    }

    return const [];
  }

  bool _canReplayMaintenanceCreateForCurrentUser(
    MaintenanceRecord local,
    String currentUid,
  ) {
    return _cleanMaintenanceText(local.loggedByUid) == currentUid;
  }

  bool _canReplayMaintenanceCloseForCurrentUser(
    _MaintenanceCloseEvidence? closeEvidence,
    String currentUid,
  ) {
    return closeEvidence != null &&
        _cleanMaintenanceText(closeEvidence.closedByUid) == currentUid;
  }

  bool _hasMaintenanceReopenEvidence(MaintenanceRecord local) {
    if (local.isResolved) return false;
    return local.resolutionHistory.isNotEmpty;
  }

  int _maintenanceCreateReplayVersion(MaintenanceRecord local) {
    if (local.version <= 1) return 1;
    if (!local.isResolved && !_hasMaintenanceReopenEvidence(local)) {
      return local.version;
    }
    if (_hasMaintenanceReopenEvidence(local)) {
      return local.version > 2 ? local.version - 2 : 1;
    }
    return local.version - 1;
  }

  Map<String, dynamic> _maintenanceCloseReplayStepData(
    MaintenanceRecord local,
    MaintenanceRecord? remote,
    int priorVersion, [
    DateTime? serverMutationFloor,
  ]) {
    final evidence = _maintenanceCloseEvidence(local);
    if (evidence == null) {
      throw StateError('Maintenance close replay requires close evidence.');
    }
    final eventTimestamp = evidence.closedAt ?? local.updatedAt;
    final mutationTimestamp =
        serverMutationFloor != null &&
                eventTimestamp.isBefore(serverMutationFloor)
            ? serverMutationFloor
            : eventTimestamp;
    final version = maintenanceCloseReplayVersion(
      localIsResolved: local.isResolved,
      localVersion: local.version,
      priorVersion: priorVersion,
      remoteVersion: remote?.version,
    );
    final burnerLockout = local.burnerLockoutCase;
    final resolvedBurnerLockout = burnerLockout?.withResolutionFromActions(
      ComponentAction.decode(
        evidence.actionsJson ?? '[]',
        source: 'maintenance replay ${local.firestoreId} closure',
      ),
    );

    return {
      'isResolved': true,
      'status': TicketStatus.resolved.name,
      'endDate': eventTimestamp.toIso8601String(),
      'closedByUid': evidence.closedByUid,
      'closedByName': evidence.closedByName,
      'remarks': evidence.remarks,
      'downtimeHours': evidence.downtimeHours,
      'teamsInvolved': evidence.teamsInvolved,
      'actionsJson': evidence.actionsJson ?? '[]',
      if (resolvedBurnerLockout != null)
        'burnerAttendedPositions': resolvedBurnerLockout.attendedPositions,
      if (resolvedBurnerLockout != null)
        'burnerResolutionEvidence':
            resolvedBurnerLockout
                .toSynchronizedFields()['burnerResolutionEvidence'],
      'updatedAt': mutationTimestamp.toUtc().toIso8601String(),
      'updatedByUid': evidence.closedByUid,
      'updatedByName': evidence.closedByName,
      'version': version,
    };
  }

  Map<String, dynamic> _maintenanceReopenReplayStepData(
    MaintenanceRecord local, [
    DateTime? serverMutationFloor,
  ]) {
    final burnerLockout = local.burnerLockoutCase;
    final mutationTimestamp =
        serverMutationFloor != null &&
                local.updatedAt.isBefore(serverMutationFloor)
            ? serverMutationFloor
            : local.updatedAt;
    return {
      'isResolved': false,
      'status': TicketStatus.open.name,
      'endDate': null,
      'closedByUid': null,
      'closedByName': null,
      'downtimeHours': null,
      'teamsInvolved': local.teamsInvolved,
      'actionsJson': local.actionsJson,
      if (burnerLockout != null) 'burnerAttendedPositions': <int>[],
      if (burnerLockout != null)
        'burnerResolutionEvidence': <String, dynamic>{},
      'remarks': local.remarks,
      'resolutionHistoryJson': local.resolutionHistoryJson,
      'updatedAt': mutationTimestamp.toUtc().toIso8601String(),
      'updatedByUid': FirebaseAuth.instance.currentUser?.uid,
      'updatedByName': null,
      'version': local.version,
    };
  }

  _MaintenanceCloseEvidence? _maintenanceCloseEvidence(
    MaintenanceRecord local,
  ) {
    if (local.isResolved) {
      final closedByUid = _cleanMaintenanceText(local.closedByUid);
      if (closedByUid == null) return null;
      return (
        closedByUid: closedByUid,
        closedByName: local.closedByName,
        closedAt: local.endDate ?? local.updatedAt,
        remarks: local.remarks,
        downtimeHours: local.downtimeHours,
        teamsInvolved: local.teamsInvolved,
        actionsJson: local.actionsJson,
      );
    }

    final history = local.resolutionHistory;
    if (history.isEmpty) return null;
    final last = history.last;
    final closedByUid = _cleanMaintenanceText(last.resolvedByUid);
    if (closedByUid == null) return null;
    return (
      closedByUid: closedByUid,
      closedByName: last.resolvedByName,
      closedAt: last.resolvedAt,
      remarks: last.remarks,
      downtimeHours: last.downtimeHours,
      teamsInvolved: last.teamsInvolved,
      actionsJson: last.actionsJson,
    );
  }

  String? _cleanMaintenanceText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _maintenancePinnedFieldDiff(
    MaintenanceRecord local,
    MaintenanceRecord remote,
  ) => maintenanceLifecycleReplayPinnedFieldDiff(local, remote);

  Future<void> _syncTemplates() async {
    final unsynced = await _plannedRepo.getUnsyncedTemplates();
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
        entityType: 'job_template',
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

      final remoteList = await _firestorePlanned.getTemplatesByFirestoreIds(
        firestoreIds,
      );
      final remoteMap = {for (var r in remoteList) r.firestoreId: r};

      final recordsToPush = <JobTemplate>[];
      final skippedButSyncedSnapshots = <SyncPushSnapshot>[];

      for (final record in activeBatchRecords) {
        if (record.firestoreId == null) {
          lastFailureCount++;
          _recordPushFailureDetail(
            entityType: 'job_template',
            entityId: 'local:${record.id}',
            error: 'Missing firestoreId for template ${record.id}',
          );
          debugPrint('❌ Missing firestoreId for template ${record.id}');
          continue;
        }

        _checkClockDrift(record.updatedAt, 'template ${record.id}');

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
          try {
            await _plannedRepo.applyTombstoneFromTemplateRemote(remote);
            lastSuccessCount++;
            debugPrint('📥 Applied remote tombstone for template ${record.id}');
          } catch (e, stackTrace) {
            lastFailureCount++;
            debugPrint(
              '❌ Failed to apply remote tombstone for template ${record.id}: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          continue;
        }

        if (remote != null && _isRemoteNewer(record, remote)) {
          await _recordPushConflict(
            entityType: 'template',
            entityId: record.firestoreId!,
            localSnapshot: record.toAuditMap(),
            remoteSnapshot: remote.toAuditMap(),
          );
          lastFailureCount++;
          debugPrint(
            '⚠️ PUSH CONFLICT: Preserved local template ${record.id} and did not overwrite newer remote data',
          );
          continue;
        }

        recordsToPush.add(record);
      }

      bool pushSuccess = false;

      if (recordsToPush.isNotEmpty) {
        try {
          await _retry(() async {
            await _firestorePlanned.batchUpsertTemplates(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'job_template',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Template batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _plannedRepo.markTemplatesSyncedIfUnchanged(snapshotsToMark);
      }
    }
  }
}

@visibleForTesting
bool maintenanceResolvedReplayCanRebase({
  required MaintenanceRecord local,
  required MaintenanceRecord remote,
  required String currentUid,
}) {
  final actorUid = currentUid.trim();
  final closedByUid = local.closedByUid?.trim();
  return local.isResolved &&
      !local.isDeleted &&
      !remote.isResolved &&
      !remote.isDeleted &&
      !remote.workflowDeferred &&
      actorUid.isNotEmpty &&
      closedByUid != null &&
      closedByUid == actorUid &&
      maintenanceLifecycleReplayPinnedFieldDiff(local, remote) == 'none';
}

@visibleForTesting
int maintenanceCloseReplayVersion({
  required bool localIsResolved,
  required int localVersion,
  required int priorVersion,
  int? remoteVersion,
}) {
  final proposedVersion = localIsResolved ? localVersion : priorVersion + 1;
  return remoteVersion != null && proposedVersion <= remoteVersion
      ? remoteVersion + 1
      : proposedVersion;
}

@visibleForTesting
String maintenanceLifecycleReplayPinnedFieldDiff(
  MaintenanceRecord local,
  MaintenanceRecord remote,
) {
  final checks = <String, bool>{
    'assetType': local.assetType == remote.assetType,
    'assetNumber': local.assetNumber == remote.assetNumber,
    'maintenanceType': local.maintenanceType == remote.maintenanceType,
    'description': local.description == remote.description,
    'routedTo': local.routedTo == remote.routedTo,
    'isCritical': local.isCritical == remote.isCritical,
    'loggedByUid': local.loggedByUid == remote.loggedByUid,
    'createdAt': local.createdAt.isAtSameMomentAs(remote.createdAt),
    'startDate': local.startDate.isAtSameMomentAs(remote.startDate),
    'component': local.component == remote.component,
    'subsystem': local.subsystem == remote.subsystem,
    'tag': local.tag == remote.tag,
    'hierarchyPath': _maintenanceReplayStringListEquals(
      local.hierarchyPath,
      remote.hierarchyPath,
    ),
    'assetHierarchyRefJson': persistedJsonEquivalent(
      local.assetHierarchyRefJson,
      remote.assetHierarchyRefJson,
    ),
    'classification': local.classification == remote.classification,
    'otherDepartment': local.otherDepartment == remote.otherDepartment,
    'reportedBy': local.reportedBy == remote.reportedBy,
    'chargeNoAtEvent': local.chargeNoAtEvent == remote.chargeNoAtEvent,
    'metadataJson': persistedJsonEquivalent(
      local.metadataJson,
      remote.metadataJson,
    ),
    'performedBy': local.performedBy == remote.performedBy,
  };

  // Acknowledgement and workflow bridge fields are server-owned projections.
  // A field-scoped close replay preserves their current remote values, so a
  // stale local copy must not mistake those advances for a business-data edit.
  for (final entry in checks.entries) {
    if (!entry.value) return entry.key;
  }
  return 'none';
}

bool _maintenanceReplayStringListEquals(List<String>? a, List<String>? b) {
  final left = a ?? const <String>[];
  final right = b ?? const <String>[];
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool maintenanceLifecycleReplayOutcomeMatches(
  Map<String, dynamic>? remote,
  Map<String, dynamic> stepData,
) {
  if (remote == null) return false;
  for (final entry in stepData.entries) {
    if (!remote.containsKey(entry.key) ||
        !_maintenanceReplayValueEquals(remote[entry.key], entry.value)) {
      return false;
    }
  }
  return true;
}

bool _maintenanceReplayValueEquals(Object? remote, Object? expected) {
  if (remote is Map && expected is Map) {
    if (remote.length != expected.length) return false;
    for (final entry in expected.entries) {
      if (!remote.containsKey(entry.key) ||
          !_maintenanceReplayValueEquals(remote[entry.key], entry.value)) {
        return false;
      }
    }
    return true;
  }
  if (remote is List && expected is List) {
    if (remote.length != expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (!_maintenanceReplayValueEquals(remote[index], expected[index])) {
        return false;
      }
    }
    return true;
  }
  return remote == expected;
}

enum _MaintenanceReplayStep { close, reopen }

typedef _MaintenanceCreationReplayResult =
    ({WorkflowCommandReceipt receipt, bool hasPostCreateLifecycle});

typedef _MaintenanceCloseEvidence =
    ({
      String closedByUid,
      String? closedByName,
      DateTime? closedAt,
      String? remarks,
      double? downtimeHours,
      List<String> teamsInvolved,
      String? actionsJson,
    });
