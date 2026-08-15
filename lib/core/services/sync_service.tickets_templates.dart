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

        if (remote != null && _isRemoteNewer(record, remote)) {
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

        final replayed = await _tryPushDecomposedMaintenanceTicket(
          record,
          remote,
        );
        if (replayed) {
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
            await _firestoreMaintenance.batchUpsertTickets(recordsToPush);
          });

          pushSuccess = true;
          lastSuccessCount += recordsToPush.length;
        } catch (e, stackTrace) {
          lastFailureCount += recordsToPush.length;
          _recordPushFailuresForBatch(
            entityType: 'maintenance_ticket',
            records: recordsToPush,
            error: e,
          );
          debugPrint('❌ Ticket batch sync failed: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final snapshotsToMark = <SyncPushSnapshot>[...skippedButSyncedSnapshots];

      if (pushSuccess) {
        snapshotsToMark.addAll(_syncPushSnapshots(recordsToPush));
      }

      if (snapshotsToMark.isNotEmpty) {
        await _maintenanceRepo.markTicketsSyncedIfUnchanged(snapshotsToMark);
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
          _MaintenanceReplayStep.createOpen =>
            _maintenanceCreateOpenReplayStepData(local, stepVersion),
          _MaintenanceReplayStep.close => _maintenanceCloseReplayStepData(
            local,
            remote,
            stepVersion,
          ),
          _MaintenanceReplayStep.reopen => _maintenanceReopenReplayStepData(
            local,
          ),
        };

        await _retry(() async {
          await _firestoreMaintenance
              .applyRemoteMaintenanceLifecycleReplayStepForSync(
                local.firestoreId!,
                stepData,
              );
        });

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

    if (remote == null) {
      if (local.isResolved) {
        if (!_canReplayMaintenanceCreateForCurrentUser(local, currentUid)) {
          return const [];
        }
        if (!_canReplayMaintenanceCloseForCurrentUser(
          closeEvidence,
          currentUid,
        )) {
          return const [];
        }
        return const [
          _MaintenanceReplayStep.createOpen,
          _MaintenanceReplayStep.close,
        ];
      }

      if (_hasMaintenanceReopenEvidence(local)) {
        if (!_canReplayMaintenanceCreateForCurrentUser(local, currentUid)) {
          return const [];
        }
        if (!_canReplayMaintenanceCloseForCurrentUser(
          closeEvidence,
          currentUid,
        )) {
          return const [];
        }
        return const [
          _MaintenanceReplayStep.createOpen,
          _MaintenanceReplayStep.close,
          _MaintenanceReplayStep.reopen,
        ];
      }

      return const [];
    }

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
      if (local.version <= remote.version) return const [];
      if (!_canReplayMaintenanceCloseForCurrentUser(
        closeEvidence,
        currentUid,
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
    if (_hasMaintenanceReopenEvidence(local)) {
      return local.version > 2 ? local.version - 2 : 1;
    }
    return local.version - 1;
  }

  Map<String, dynamic> _maintenanceCreateOpenReplayStepData(
    MaintenanceRecord local,
    int version,
  ) {
    return {
      ...local.qualityIntentSynchronizedFields,
      ...local.burnerLockoutSynchronizedFields,
      'firestoreId': local.firestoreId,
      'version': version < 1 ? 1 : version,
      'assetType': local.assetType.name,
      'assetNumber': local.assetNumber,
      'component': local.component,
      'subsystem': local.subsystem,
      'tag': local.tag,
      'hierarchyPath': local.hierarchyPath,
      'maintenanceType': local.maintenanceType.name,
      'classification': local.classification,
      'description': local.description,
      'routedTo': local.routedTo.name,
      'otherDepartment': local.otherDepartment,
      'status': TicketStatus.open.name,
      'isResolved': false,
      'isCritical': local.isCritical,
      'loggedByUid': local.loggedByUid,
      'loggedByName': local.loggedByName,
      'reportedBy': local.reportedBy,
      'startDate': local.startDate.toIso8601String(),
      'chargeNoAtEvent': local.chargeNoAtEvent,
      'createdAt': local.createdAt.toIso8601String(),
      'updatedAt': local.createdAt.toIso8601String(),
      'metadataJson': local.metadataJson,
      'actionsJson': '[]',
      'resolutionHistoryJson': '[]',
      'isDeleted': false,
    };
  }

  Map<String, dynamic> _maintenanceCloseReplayStepData(
    MaintenanceRecord local,
    MaintenanceRecord? remote,
    int priorVersion,
  ) {
    final evidence = _maintenanceCloseEvidence(local);
    if (evidence == null) {
      throw StateError('Maintenance close replay requires close evidence.');
    }
    final timestamp = evidence.closedAt ?? local.updatedAt;
    final proposedVersion = local.isResolved ? local.version : priorVersion + 1;
    final remoteVersion = remote?.version;
    final version =
        remoteVersion != null && proposedVersion <= remoteVersion
            ? remoteVersion + 1
            : proposedVersion;
    final burnerLockout = local.burnerLockoutCase;

    return {
      'isResolved': true,
      'status': TicketStatus.resolved.name,
      'endDate': timestamp.toIso8601String(),
      'closedByUid': evidence.closedByUid,
      'closedByName': evidence.closedByName,
      'remarks': evidence.remarks,
      'downtimeHours': evidence.downtimeHours,
      'teamsInvolved': evidence.teamsInvolved,
      'actionsJson': evidence.actionsJson ?? '[]',
      if (burnerLockout != null)
        'burnerAttendedPositions': burnerLockout.attendedPositions,
      if (burnerLockout != null)
        'burnerResolutionOutcomes': <String>[
          for (final position in burnerLockout.attendedPositions)
            burnerLockout.resolutionOutcomes[position]!.name,
        ],
      'updatedAt': timestamp.toIso8601String(),
      'updatedByUid': evidence.closedByUid,
      'updatedByName': evidence.closedByName,
      'version': version,
    };
  }

  Map<String, dynamic> _maintenanceReopenReplayStepData(
    MaintenanceRecord local,
  ) {
    final burnerLockout = local.burnerLockoutCase;
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
      if (burnerLockout != null) 'burnerResolutionOutcomes': <String>[],
      'remarks': local.remarks,
      'resolutionHistoryJson': local.resolutionHistoryJson,
      'updatedAt': local.updatedAt.toIso8601String(),
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
      'hierarchyPath': _maintenanceStringListEquals(
        local.hierarchyPath,
        remote.hierarchyPath,
      ),
      'classification': local.classification == remote.classification,
      'otherDepartment': local.otherDepartment == remote.otherDepartment,
      'reportedBy': local.reportedBy == remote.reportedBy,
      'acknowledgedByUid': local.acknowledgedByUid == remote.acknowledgedByUid,
      'acknowledgedByName':
          local.acknowledgedByName == remote.acknowledgedByName,
      'acknowledgedAt': _maintenanceNullableDateEquals(
        local.acknowledgedAt,
        remote.acknowledgedAt,
      ),
      'chargeNoAtEvent': local.chargeNoAtEvent == remote.chargeNoAtEvent,
      'metadataJson': local.metadataJson == remote.metadataJson,
      'performedBy': local.performedBy == remote.performedBy,
    };

    for (final entry in checks.entries) {
      if (!entry.value) return entry.key;
    }
    return 'none';
  }

  bool _maintenanceStringListEquals(List<String>? a, List<String>? b) {
    final left = a ?? const <String>[];
    final right = b ?? const <String>[];
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _maintenanceNullableDateEquals(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

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

enum _MaintenanceReplayStep { createOpen, close, reopen }

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
