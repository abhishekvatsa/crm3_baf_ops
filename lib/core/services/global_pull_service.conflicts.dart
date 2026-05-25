part of 'global_pull_service.dart';

// ─────────────────────────────────────────────────────────────
// CONFLICT HELPERS
// ─────────────────────────────────────────────────────────────

// Sync-winner policy note:
//
// Remote *updates* are evaluated with a version-primary rule, using
// updatedAt only as the tie-breaker when versions match. This mirrors the
// push path's _isRemoteNewer contract and prevents a lower-version remote
// edit from displacing a newer local version merely because clocks differ.
//
// Dirty local rows are still treated as loss-sensitive evidence. When a
// local row is unsynced and the remote row is strictly newer by the
// version-primary rule, this pull service preserves the local row, records a
// pull conflict via _logPullConflict(), and emits a high-severity audit event
// through _logConflictAudit(). When the remote row is not strictly newer, the
// local dirty row is also preserved and counted as skipped.
//
// Clean local rows use an additional timestamp guard: if the local row is
// already synced but its updatedAt is after the fetched remote row, the remote
// row is skipped. This is deliberate clock-skew protection for unmanaged
// tablets and stale delta windows; it is not the dirty-row conflict path.
//
// Remote *tombstones* are more destructive than normal updates, so tombstone
// application remains delegated to repository-level applyTombstoneFrom*Remote
// helpers. Those helpers preserve fresher unsynced local evidence and return
// RemoteTombstoneApplyResult so this service can count/audit the conflict.
// Do not collapse tombstone handling into the normal update-winner branch.

extension _GlobalPullConflicts on GlobalPullService {
  String _conflictKey(String entityLabel, dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return '$entityLabel:$firestoreId';
      }
    } catch (_) {
      // Fall through to local id.
    }

    try {
      return '$entityLabel:local:${record.id}';
    } catch (_) {
      return '$entityLabel:unknown';
    }
  }

  bool _isRemoteNewer(dynamic local, dynamic remote) {
    return SyncRemoteFreshnessPolicy.isRemoteNewer(
      localVersion: local.version as int,
      localUpdatedAt: local.updatedAt as DateTime,
      remoteVersion: remote.version as int,
      remoteUpdatedAt: remote.updatedAt as DateTime,
    );
  }

  Object? _jsonSafeValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.name;
    if (value is Iterable) return value.map((v) => _jsonSafeValue(v)).toList();
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _jsonSafeValue(mapValue)),
      );
    }
    return value.toString();
  }

  Map<String, dynamic> _safeAuditMap(dynamic record) {
    try {
      final dynamic raw = record.toAuditMap();
      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry(key.toString(), _jsonSafeValue(value)),
        );
      }
    } catch (_) {
      // Fall back to a small sync metadata snapshot.
    }

    dynamic readField(String name) {
      try {
        switch (name) {
          case 'firestoreId':
            return record.firestoreId;
          case 'id':
            return record.id;
          case 'version':
            return record.version;
          case 'updatedAt':
            return record.updatedAt;
          case 'isDeleted':
            return record.isDeleted;
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    return {
      'firestoreId': _jsonSafeValue(readField('firestoreId')),
      'localId': _jsonSafeValue(readField('id')),
      'version': _jsonSafeValue(readField('version')),
      'updatedAt': _jsonSafeValue(readField('updatedAt')),
      'isDeleted': _jsonSafeValue(readField('isDeleted')),
    };
  }

  String _auditEntityId(dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return firestoreId;
      }
    } catch (_) {
      // Fall through to local id.
    }

    try {
      return record.id.toString();
    } catch (_) {
      return 'unknown';
    }
  }

  void _logConflictAudit(
    String entityLabel,
    dynamic local,
    dynamic remote, {
    String? reasonNotes,
    String? summary,
    AuditAction action = AuditAction.update,
  }) {
    final normalizedEntityType = entityLabel.replaceAll(' ', '_');
    final localMap = _safeAuditMap(local);
    final remoteMap = _safeAuditMap(remote);

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final actorUid = firebaseUser?.uid;
    final actorName =
        firebaseUser?.displayName?.trim().isNotEmpty == true
            ? firebaseUser!.displayName!.trim()
            : firebaseUser?.email?.trim().isNotEmpty == true
            ? firebaseUser!.email!.trim()
            : 'Sync Engine';

    final event = AuditEvent(
      entityType: normalizedEntityType,
      entityId: _auditEntityId(local),
      action: action,
      performedByUid: actorUid ?? 'sync_engine',
      performedByName:
          actorUid == null ? 'Sync Engine' : 'Sync Engine ($actorName)',
      reason: AuditReason.manualOverride,
      reasonNotes:
          reasonNotes ??
          'Sync conflict preserved: unsynced local record was retained because remote was newer.',
      summary: summary ?? 'Sync conflict preserved for $entityLabel',
      severity: AuditSeverity.high,
      before: localMap,
      after: remoteMap,
    );

    unawaited(
      _auditRepo.log(event, syncToRemote: actorUid != null).catchError((
        Object error,
      ) {
        debugPrint('⚠️ Failed to audit sync conflict: $error');
      }),
    );
  }

  void _logPullConflict(String entityLabel, dynamic local, dynamic remote) {
    lastConflicted++;
    lastSkipped++;
    lastConflictKeys.add(_conflictKey(entityLabel, local));
    debugPrint(
      '⚠️ PULL CONFLICT: Retaining unsynced local $entityLabel ${local.id}; '
      'remote is newer and was not applied. firestoreId=${local.firestoreId}, '
      'local.version=${local.version}, remote.version=${remote.version}, '
      'local.updatedAt=${local.updatedAt}, remote.updatedAt=${remote.updatedAt}',
    );
    _logConflictAudit(entityLabel, local, remote);
  }

  void _recordTombstoneApplyResult(
    String entityLabel,
    dynamic remote,
    RemoteTombstoneApplyResult result,
  ) {
    switch (result.outcome) {
      case RemoteTombstoneApplyOutcome.applied:
        lastDeleted++;
        return;
      case RemoteTombstoneApplyOutcome.localDirtyPreserved:
        final local = result.localRecord;
        lastConflicted++;
        lastSkipped++;
        if (local != null) {
          lastConflictKeys.add(_conflictKey(entityLabel, local));
        } else {
          lastConflictKeys.add(_conflictKey(entityLabel, remote));
        }
        debugPrint(
          '⚠️ TOMBSTONE CONFLICT: Retaining fresher unsynced local $entityLabel; '
          'remote tombstone was not applied. firestoreId=${remote.firestoreId}, '
          'remote.deletedAt=${remote.deletedAt}, remote.updatedAt=${remote.updatedAt}',
        );
        if (local != null) {
          _logConflictAudit(
            entityLabel,
            local,
            remote,
            reasonNotes:
                'Sync conflict preserved: remote tombstone conflicted with fresher unsynced local evidence; the remote delete was not applied.',
            summary:
                'Sync conflict preserved for $entityLabel: remote tombstone not applied',
            action: AuditAction.delete,
          );
        }
        return;
      case RemoteTombstoneApplyOutcome.localMissing:
      case RemoteTombstoneApplyOutcome.alreadyDeleted:
      case RemoteTombstoneApplyOutcome.notDeletedRemote:
        lastSkipped++;
        return;
    }
  }
}
