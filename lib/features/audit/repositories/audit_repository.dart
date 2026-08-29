// FILE: lib/features/audit/repositories/audit_repository.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../models/audit_event_model.dart';

AuditEvent decodePersistedAuditEvent(
  Map<String, dynamic> data, {
  required String documentId,
}) {
  final source = 'audit_logs/$documentId';
  final event =
      AuditEvent(
          entityType: readRequiredPersistedString(
            data['entityType'],
            field: 'entityType',
            source: source,
          ),
          entityId: readRequiredPersistedString(
            data['entityId'],
            field: 'entityId',
            source: source,
          ),
          action: readRequiredPersistedEnum(
            AuditAction.values,
            data['action'],
            field: 'action',
            source: source,
          ),
          performedByUid: readRequiredPersistedString(
            data['performedByUid'],
            field: 'performedByUid',
            source: source,
          ),
          performedByName: readOptionalPersistedString(
            data['performedByName'],
            field: 'performedByName',
            source: source,
          ),
          reason: readOptionalPersistedEnum(
            AuditReason.values,
            data['reason'],
            field: 'reason',
            source: source,
          ),
          reasonNotes: readOptionalPersistedString(
            data['reasonNotes'],
            field: 'reasonNotes',
            source: source,
          ),
          summary: readOptionalPersistedString(
            data['summary'],
            field: 'summary',
            source: source,
          ),
          severity: readRequiredPersistedEnum(
            AuditSeverity.values,
            data['severity'],
            field: 'severity',
            source: source,
          ),
          before: readOptionalJsonObject(
            data['beforeJson'] ?? data['before'],
            field: 'beforeJson',
            source: source,
          ),
          after: readOptionalJsonObject(
            data['afterJson'] ?? data['after'],
            field: 'afterJson',
            source: source,
          ),
        )
        ..timestamp = readRequiredPersistedDateTime(
          data['timestamp'],
          field: 'timestamp',
          source: source,
          allowEpochMilliseconds: true,
        )
        ..remoteDocumentId = documentId
        ..isSynced = true;
  return event;
}

class AuditSyncResult {
  final int attempted;
  final int synced;
  final int failed;
  final int batchFailureCount;

  const AuditSyncResult({
    required this.attempted,
    required this.synced,
    required this.failed,
    required this.batchFailureCount,
  });

  static const empty = AuditSyncResult(
    attempted: 0,
    synced: 0,
    failed: 0,
    batchFailureCount: 0,
  );

  bool get hasFailures => failed > 0 || batchFailureCount > 0;
}

class AuditRepository {
  static const int _remoteEntityPageSize = 100;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('audit_logs');

  // ─────────────────────────────────────────────
  // LOCAL (SOURCE OF TRUTH)
  // ─────────────────────────────────────────────

  Future<void> logLocal(AuditEvent event) async {
    if (kIsWeb) {
      debugPrint('ℹ️ Skipping local audit log on web');
      return;
    }

    await isar.writeTxn(() async {
      event.isSynced = false;
      await isar.auditEvents.put(event);
    });
  }

  Future<List<AuditEvent>> getLocalEventsForEntity(
    String entityType,
    String entityId,
  ) async {
    if (kIsWeb) {
      return _getAllRemoteEventsForEntity(entityType, entityId);
    }

    final local =
        await isar.auditEvents
            .filter()
            .entityTypeEqualTo(entityType)
            .and()
            .entityIdEqualTo(entityId)
            .sortByTimestampDesc()
            .findAll();

    try {
      final remote = await _getAllRemoteEventsForEntity(entityType, entityId);
      return _mergeAuditEvents(local, remote);
    } on PersistedDataFormatException {
      rethrow;
    } catch (e) {
      debugPrint(
        '⚠️ Remote audit timeline unavailable for $entityType/$entityId; using local history only: $e',
      );
      return local;
    }
  }

  Future<List<AuditEvent>> getRecentLocalEvents({int limit = 100}) async {
    if (kIsWeb) {
      return getRecentRemoteEvents(limit: limit);
    }

    final local =
        await isar.auditEvents
            .where()
            .sortByTimestampDesc()
            .limit(limit)
            .findAll();

    try {
      final remote = await getRecentRemoteEvents(limit: limit);
      return _mergeAuditEvents(local, remote).take(limit).toList();
    } on PersistedDataFormatException {
      rethrow;
    } catch (e) {
      debugPrint(
        '⚠️ Remote recent audit events unavailable; using local only: $e',
      );
      return local;
    }
  }

  Future<List<AuditEvent>> getRecentSyncConflictEvents({
    int limit = 100,
  }) async {
    final scanLimit = (limit * 5).clamp(limit, 500).toInt();

    final localCandidates = <AuditEvent>[];

    if (!kIsWeb) {
      localCandidates.addAll(
        await isar.auditEvents
            .where()
            .sortByTimestampDesc()
            .limit(scanLimit)
            .findAll(),
      );
    }

    try {
      final remoteCandidates = await getRecentRemoteEvents(limit: scanLimit);
      return _mergeAuditEvents(
        localCandidates,
        remoteCandidates,
      ).where(_isSyncConflictEvent).take(limit).toList();
    } on PersistedDataFormatException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Remote sync-conflict audit scan unavailable: $e');
      return localCandidates.where(_isSyncConflictEvent).take(limit).toList();
    }
  }

  bool _isSyncConflictEvent(AuditEvent event) {
    final summary = event.summary?.toLowerCase() ?? '';
    final notes = event.reasonNotes?.toLowerCase() ?? '';

    return event.performedByUid == 'sync_engine' ||
        summary.contains('sync conflict') ||
        notes.contains('sync conflict');
  }

  // ─────────────────────────────────────────────
  // REMOTE (FIRESTORE)
  // ─────────────────────────────────────────────

  Future<void> logRemote(AuditEvent event) async {
    await _collection
        .doc(_remoteDocumentId(event))
        .set(_eventToMap(event), SetOptions(merge: true));
  }

  Future<List<AuditEvent>> getRemoteEventsForEntity(
    String entityType,
    String entityId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _collection
        .where('entityType', isEqualTo: entityType)
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs.map(_mapEvent).toList();
  }

  Future<List<AuditEvent>> getMaintenanceTicketCorrectionEvents(
    String ticketId,
  ) async {
    final cleanTicketId = ticketId.trim();
    if (cleanTicketId.isEmpty || cleanTicketId.length > 200) {
      throw ArgumentError.value(
        ticketId,
        'ticketId',
        'A valid maintenance ticket ID is required.',
      );
    }

    final events = <AuditEvent>[];
    DocumentSnapshot<Map<String, dynamic>>? startAfter;
    while (true) {
      var query = _collection
          .where('entityType', isEqualTo: 'maintenance')
          .where('entityId', isEqualTo: cleanTicketId)
          .where('operation', isEqualTo: 'correctMaintenanceTicket')
          .orderBy('timestamp', descending: true)
          .limit(_remoteEntityPageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      events.addAll(snapshot.docs.map(_mapEvent));
      if (snapshot.docs.length < _remoteEntityPageSize) break;
      startAfter = snapshot.docs.last;
    }
    return List<AuditEvent>.unmodifiable(events);
  }

  Future<List<AuditEvent>> getRecentRemoteEvents({int limit = 100}) async {
    final snap =
        await _collection
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

    return snap.docs.map(_mapEvent).toList();
  }

  // ─────────────────────────────────────────────
  // UNIFIED LOG (LOCAL + BEST-EFFORT REMOTE)
  // ─────────────────────────────────────────────

  Future<void> log(AuditEvent event, {bool syncToRemote = true}) async {
    if (kIsWeb) {
      if (!syncToRemote) {
        debugPrint(
          'ℹ️ Skipping audit log on web because syncToRemote is false',
        );
        return;
      }

      await logRemote(event);
      return;
    }

    await logLocal(event);

    if (syncToRemote) {
      try {
        await logRemote(event);

        await isar.writeTxn(() async {
          event.isSynced = true;
          await isar.auditEvents.put(event);
        });
      } catch (e) {
        debugPrint('⚠️ Audit remote log failed (will retry): $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // SYNC RETRY (CRITICAL)
  // ─────────────────────────────────────────────

  Future<AuditSyncResult> syncPendingAuditEvents({int batchSize = 450}) async {
    if (kIsWeb) return AuditSyncResult.empty;

    final effectiveBatchSize = batchSize.clamp(1, 450).toInt();
    final unsynced =
        await isar.auditEvents.filter().isSyncedEqualTo(false).findAll();

    if (unsynced.isEmpty) return AuditSyncResult.empty;

    unsynced.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var synced = 0;
    var failed = 0;
    var batchFailures = 0;

    for (var i = 0; i < unsynced.length; i += effectiveBatchSize) {
      final chunk = unsynced.sublist(
        i,
        i + effectiveBatchSize > unsynced.length
            ? unsynced.length
            : i + effectiveBatchSize,
      );

      try {
        await logBatchRemote(chunk);
        await _markLocalAuditEventsSynced(chunk);
        synced += chunk.length;
      } catch (error, stackTrace) {
        batchFailures++;
        debugPrint(
          '⚠️ Pending audit batch sync failed for ${chunk.length} event(s): $error',
        );
        AppLogger.warning(
          'Pending audit batch sync failed; falling back to per-event sync',
          error: error,
          stackTrace: stackTrace,
          context: {
            'app_area': 'audit',
            'audit_pending_chunk_size': chunk.length,
          },
        );

        final fallback = await _syncPendingAuditEventsIndividually(chunk);
        synced += fallback.synced;
        failed += fallback.failed;
      }
    }

    final result = AuditSyncResult(
      attempted: unsynced.length,
      synced: synced,
      failed: failed,
      batchFailureCount: batchFailures,
    );

    if (result.hasFailures) {
      AppLogger.warning(
        'Pending audit sync completed with failures',
        context: {
          'app_area': 'audit',
          'audit_pending_attempted': result.attempted,
          'audit_pending_synced': result.synced,
          'audit_pending_failed': result.failed,
          'audit_batch_failures': result.batchFailureCount,
        },
      );
    }

    return result;
  }

  Future<AuditSyncResult> _syncPendingAuditEventsIndividually(
    List<AuditEvent> events,
  ) async {
    var synced = 0;
    var failed = 0;

    for (final event in events) {
      try {
        await logRemote(event);
        await _markLocalAuditEventsSynced([event]);
        synced++;
      } catch (error, stackTrace) {
        failed++;
        debugPrint(
          '⚠️ Pending audit event sync failed for '
          '${event.entityType}/${event.entityId}: $error',
        );
        AppLogger.warning(
          'Pending audit event sync failed',
          error: error,
          stackTrace: stackTrace,
          context: {
            'app_area': 'audit',
            'audit_entity_type': event.entityType,
            'audit_entity_id': event.entityId,
          },
        );
      }
    }

    return AuditSyncResult(
      attempted: events.length,
      synced: synced,
      failed: failed,
      batchFailureCount: 0,
    );
  }

  Future<void> _markLocalAuditEventsSynced(List<AuditEvent> events) async {
    if (events.isEmpty || kIsWeb) return;

    await isar.writeTxn(() async {
      for (final event in events) {
        event.isSynced = true;
      }
      await isar.auditEvents.putAll(events);
    });
  }

  // ─────────────────────────────────────────────
  // OPTIONAL: BULK REMOTE LOGGING
  // ─────────────────────────────────────────────

  Future<void> logBatchRemote(List<AuditEvent> events) async {
    for (var i = 0; i < events.length; i += 500) {
      final chunk = events.sublist(
        i,
        i + 500 > events.length ? events.length : i + 500,
      );
      final batch = _collection.firestore.batch();

      for (final e in chunk) {
        final doc = _collection.doc(_remoteDocumentId(e));
        batch.set(doc, _eventToMap(e), SetOptions(merge: true));
      }

      await batch.commit();
    }
  }

  // ─────────────────────────────────────────────
  // WEB FALLBACK HELPERS
  // ─────────────────────────────────────────────

  Future<List<AuditEvent>> _getAllRemoteEventsForEntity(
    String entityType,
    String entityId,
  ) async {
    final events = <AuditEvent>[];
    DocumentSnapshot? startAfter;

    while (true) {
      var query = _collection
          .where('entityType', isEqualTo: entityType)
          .where('entityId', isEqualTo: entityId)
          .orderBy('timestamp', descending: true)
          .limit(_remoteEntityPageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();

      if (snap.docs.isEmpty) {
        break;
      }

      events.addAll(snap.docs.map(_mapEvent));

      if (snap.docs.length < _remoteEntityPageSize) {
        break;
      }

      startAfter = snap.docs.last;
    }

    return events;
  }

  List<AuditEvent> _mergeAuditEvents(
    List<AuditEvent> primary,
    List<AuditEvent> secondary,
  ) {
    final byKey = <String, AuditEvent>{};

    for (final event in [...primary, ...secondary]) {
      byKey[_eventMergeKey(event)] = event;
    }

    final merged =
        byKey.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return merged;
  }

  String _eventMergeKey(AuditEvent event) {
    return [
      event.entityType,
      event.entityId,
      event.action.name,
      event.performedByUid,
      event.timestamp.toUtc().microsecondsSinceEpoch.toString(),
      event.reason?.name ?? '',
      event.reasonNotes ?? '',
      event.summary ?? '',
      event.severity.name,
      event.beforeJson ?? '',
      event.afterJson ?? '',
    ].join('|');
  }

  // ─────────────────────────────────────────────
  // STABLE REMOTE ID HELPERS
  // ─────────────────────────────────────────────

  String _remoteDocumentId(AuditEvent event) {
    final fingerprint = [
      event.id.toString(),
      event.entityType,
      event.entityId,
      event.action.name,
      event.performedByUid,
      event.timestamp.toUtc().microsecondsSinceEpoch.toString(),
      event.reason?.name ?? '',
      event.reasonNotes ?? '',
      event.summary ?? '',
      event.severity.name,
      event.beforeJson ?? '',
      event.afterJson ?? '',
    ].join('|');

    final actor = _safeDocPart(event.performedByUid);
    final timestamp = event.timestamp.toUtc().microsecondsSinceEpoch;
    final hash = _stableHash(fingerprint);

    return 'audit_${actor}_${event.id}_${timestamp}_$hash';
  }

  String _safeDocPart(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safe.isEmpty) return 'unknown';
    if (safe.length <= 80) return safe;
    return safe.substring(0, 80);
  }

  String _stableHash(String input) {
    var hash = 0x811c9dc5;

    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ─────────────────────────────────────────────
  // MAPPERS
  // ─────────────────────────────────────────────

  Map<String, dynamic> _eventToMap(AuditEvent e) => {
    'entityType': e.entityType,
    'entityId': e.entityId,
    'action': e.action.name,
    'performedByUid': e.performedByUid,
    'performedByName': e.performedByName,
    'timestamp': Timestamp.fromDate(e.timestamp),
    'reason': e.reason?.name,
    'reasonNotes': e.reasonNotes,
    'summary': e.summary,
    'severity': e.severity.name,
    'beforeJson': e.beforeJson,
    'afterJson': e.afterJson,
  };

  AuditEvent _mapEvent(DocumentSnapshot<Map<String, dynamic>> doc) =>
      decodePersistedAuditEvent(doc.data()!, documentId: doc.id);
}
