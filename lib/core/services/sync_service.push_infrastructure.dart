part of 'sync_service.dart';

extension _SyncServicePushInfrastructure on SyncService {
  Future<void> _retry(
    Future<void> Function() task, {
    int maxAttempts = 3,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    final rand = Random();

    while (true) {
      try {
        await task();
        return;
      } catch (e) {
        attempt++;

        if (shouldRetry != null && !shouldRetry(e)) rethrow;
        if (attempt >= maxAttempts) rethrow;

        final baseDelay = Duration(seconds: 2 * attempt);
        final jitter = Duration(milliseconds: rand.nextInt(150));
        final delay = baseDelay + jitter;

        debugPrint('⚠️ Retry $attempt after ${delay.inMilliseconds}ms → $e');

        await Future.delayed(delay);
      }
    }
  }

  void _sortDeletesFirst(List<dynamic> items) {
    items.sort((a, b) {
      if (a.isDeleted && !b.isDeleted) return -1;
      if (!a.isDeleted && b.isDeleted) return 1;
      return a.updatedAt.compareTo(b.updatedAt);
    });
  }

  void _checkClockDrift(DateTime updatedAt, String label) {
    final now = DateTime.now();

    if (updatedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      debugPrint('⚠️ Clock drift detected for $label');
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

  SyncPushSnapshot _syncPushSnapshot(dynamic record) {
    return SyncPushSnapshot(
      id: record.id as int,
      version: record.version as int,
      updatedAt: record.updatedAt as DateTime,
    );
  }

  List<SyncPushSnapshot> _syncPushSnapshots(Iterable<dynamic> records) {
    return records
        .map((record) => _syncPushSnapshot(record))
        .toList(growable: false);
  }

  SyncFailureDetail _buildPushFailureDetail({
    required String entityType,
    required String entityId,
    required Object error,
    String? firestoreId,
  }) {
    final populationError =
        error is RuntimeJobModulePopulationException ? error : null;
    final abnormalityError =
        error is ChargeAbnormalityMutationException ? error : null;
    final firebaseError = error is FirebaseException ? error : null;
    final message =
        populationError?.operatorMessage ??
        abnormalityError?.operatorMessage ??
        (firebaseError?.message?.trim().isNotEmpty == true
            ? firebaseError!.message!.trim()
            : error.toString());
    final errorCode =
        populationError?.code ?? abnormalityError?.code ?? firebaseError?.code;
    final isLikelyPermanent =
        populationError?.isDurableRejection ??
        abnormalityError?.isDurableRejection ??
        (firebaseError != null &&
            (firebaseError.code == 'permission-denied' ||
                firebaseError.code == 'failed-precondition' ||
                firebaseError.code == 'invalid-argument'));
    return SyncFailureDetail(
      entityType: entityType,
      entityId: entityId,
      message: message,
      errorCode: errorCode,
      firestoreId: firestoreId,
      isLikelyPermanent: isLikelyPermanent,
      occurredAt: DateTime.now(),
    );
  }

  void _appendPushFailureDetail(SyncFailureDetail detail) {
    if (lastFailureDetails.length >= SyncService._maxFailureDetails) {
      lastFailureDetailOverflowCount++;
      return;
    }
    lastFailureDetails.add(detail);
  }

  void _recordPushFailureDetail({
    required String entityType,
    required String entityId,
    required Object error,
    String? firestoreId,
  }) {
    final detail = _buildPushFailureDetail(
      entityType: entityType,
      entityId: entityId,
      error: error,
      firestoreId: firestoreId,
    );
    unawaited(_upsertSyncRejection(detail));
    _appendPushFailureDetail(detail);
  }

  /// Population-fence rejections are awaited so a sync pass cannot return
  /// before the durable local rejection record is safely written.
  Future<void> _recordJobModulePopulationFailure({
    required JobModuleInstance record,
    required Object error,
  }) async {
    final detail = _buildPushFailureDetail(
      entityType: 'job_module',
      entityId: _syncEntityId(record),
      firestoreId: _syncFirestoreId(record),
      error: error,
    );
    await _upsertSyncRejection(detail, failClosed: true);
    _appendPushFailureDetail(detail);
  }

  Future<void> _upsertSyncRejection(
    SyncFailureDetail detail, {
    bool failClosed = false,
  }) async {
    if (kIsWeb) {
      return;
    }
    final localIsar = Isar.getInstance();
    if (localIsar == null) {
      if (failClosed) {
        throw StateError(
          'A durable population rejection could not be persisted because the '
          'local Isar database is unavailable.',
        );
      }
      return;
    }

    try {
      await localIsar.writeTxn(() async {
        final existing =
            await localIsar.syncRejections
                .filter()
                .entityTypeEqualTo(detail.entityType)
                .and()
                .entityIdEqualTo(detail.entityId)
                .and()
                .isResolvedEqualTo(false)
                .findFirst();

        if (existing != null) {
          existing.markSeenAgain(
            message: detail.message,
            errorCode: detail.errorCode,
            firestoreId: detail.firestoreId,
            isLikelyPermanent: detail.isLikelyPermanent,
            at: detail.occurredAt,
          );
          await localIsar.syncRejections.put(existing);
          return;
        }

        final rejection =
            SyncRejection()
              ..entityType = detail.entityType
              ..entityId = detail.entityId
              ..firestoreId = detail.firestoreId
              ..errorCode = detail.errorCode
              ..message = detail.message
              ..firstSeenAt = detail.occurredAt
              ..lastSeenAt = detail.occurredAt
              ..attemptCount = 1
              ..isLikelyPermanent = detail.isLikelyPermanent
              ..isResolved = false;
        await localIsar.syncRejections.put(rejection);
      });
    } catch (e, st) {
      debugPrint(
        '⚠️ Failed to persist sync rejection for ${detail.shortLabel}: $e',
      );
      debugPrint('$st');
      if (failClosed) rethrow;
    }
  }

  void _recordPushFailuresForBatch({
    required String entityType,
    required Iterable<dynamic> records,
    required Object error,
  }) {
    for (final record in records) {
      _recordPushFailureDetail(
        entityType: entityType,
        entityId: _syncEntityId(record),
        firestoreId: _syncFirestoreId(record),
        error: error,
      );
    }
  }

  Future<List<T>> _recordsEligibleForAutomaticPush<T>({
    required String entityType,
    required List<T> records,
  }) async {
    if (records.isEmpty || kIsWeb) return records;

    final localIsar = Isar.getInstance();
    if (localIsar == null) return records;

    final candidateEntityIds = <String>{
      for (final record in records) _syncEntityId(record),
    };
    final candidateFirestoreIds = <String>{};
    for (final record in records) {
      final firestoreId = _syncFirestoreId(record);
      if (firestoreId != null) {
        candidateFirestoreIds.add(firestoreId);
      }
    }

    if (candidateEntityIds.isEmpty && candidateFirestoreIds.isEmpty) {
      return records;
    }

    List<SyncRejection> permanentRejections;
    try {
      permanentRejections =
          await localIsar.syncRejections
              .filter()
              .entityTypeEqualTo(entityType)
              .and()
              .isResolvedEqualTo(false)
              .and()
              .isLikelyPermanentEqualTo(true)
              .findAll();
    } catch (e, st) {
      debugPrint(
        '⚠️ Could not inspect sync rejection hold state for $entityType: $e',
      );
      debugPrint('$st');
      return records;
    }

    final rejectionsByEntityId = <String, SyncRejection>{};
    for (final rejection in permanentRejections) {
      if (candidateEntityIds.contains(rejection.entityId)) {
        rejectionsByEntityId[rejection.entityId] = rejection;
      }
      final firestoreId = rejection.firestoreId?.trim();
      if (firestoreId != null &&
          firestoreId.isNotEmpty &&
          candidateFirestoreIds.contains(firestoreId)) {
        rejectionsByEntityId[firestoreId] = rejection;
      }
    }

    if (rejectionsByEntityId.isEmpty) return records;

    final eligible = <T>[];
    for (final record in records) {
      final entityId = _syncEntityId(record);
      final firestoreId = _syncFirestoreId(record);
      final rejection =
          rejectionsByEntityId[entityId] ??
          (firestoreId == null ? null : rejectionsByEntityId[firestoreId]);

      if (rejection == null) {
        eligible.add(record);
        continue;
      }

      _recordAutomaticRetryHeld(
        entityType: entityType,
        entityId: entityId,
        firestoreId: firestoreId,
        rejection: rejection,
      );
    }

    return eligible;
  }

  void _recordAutomaticRetryHeld({
    required String entityType,
    required String entityId,
    required SyncRejection rejection,
    String? firestoreId,
  }) {
    lastFailureCount++;
    lastConflictKeys.add('$entityType:$entityId');

    if (lastFailureDetails.length >= SyncService._maxFailureDetails) {
      lastFailureDetailOverflowCount++;
      return;
    }

    lastFailureDetails.add(
      SyncFailureDetail(
        entityType: entityType,
        entityId: entityId,
        firestoreId: firestoreId ?? rejection.firestoreId,
        errorCode: rejection.errorCode ?? 'sync-rejection-held',
        message:
            'Automatic retry held because an unresolved likely permanent sync rejection exists. '
            'Review or resolve the rejection before retrying. Last rejection: ${rejection.displayMessage}',
        isLikelyPermanent: true,
        occurredAt: DateTime.now(),
      ),
    );

    debugPrint(
      '🛑 Held automatic sync retry for $entityType/$entityId due to unresolved permanent rejection: ${rejection.displayMessage}',
    );
  }

  String? _syncFirestoreId(dynamic record) {
    try {
      final firestoreId = record.firestoreId;
      if (firestoreId is String && firestoreId.trim().isNotEmpty) {
        return firestoreId.trim();
      }
    } catch (_) {
      // No firestoreId field or unreadable value.
    }
    return null;
  }

  String _syncEntityId(dynamic record) {
    final firestoreId = _syncFirestoreId(record);
    if (firestoreId != null) return firestoreId;

    try {
      return 'local:${record.id}';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _recordPushConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localSnapshot,
    required Map<String, dynamic> remoteSnapshot,
  }) async {
    lastConflictCount++;
    lastConflictKeys.add('$entityType:$entityId');

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final actorUid = firebaseUser?.uid;
    final actorName =
        firebaseUser?.displayName?.trim().isNotEmpty == true
            ? firebaseUser!.displayName!.trim()
            : firebaseUser?.email?.trim().isNotEmpty == true
            ? firebaseUser!.email!.trim()
            : 'Sync Engine';

    try {
      await _auditRepo.log(
        AuditEvent(
          entityType: entityType,
          entityId: entityId,
          action: AuditAction.update,
          performedByUid: actorUid ?? 'sync_engine',
          performedByName:
              actorUid == null ? 'Sync Engine' : 'Sync Engine ($actorName)',
          reasonNotes:
              'Sync conflict preserved during push. Local unsynced record was not pushed over newer remote data.',
          summary: 'Sync conflict preserved during push',
          severity: AuditSeverity.high,
          before: localSnapshot,
          after: remoteSnapshot,
        ),
        syncToRemote: actorUid != null,
      );
    } catch (e) {
      debugPrint(
        '⚠️ Failed to audit push conflict for $entityType/$entityId: $e',
      );
    }
  }

  String? _cleanText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _sameStringList(List<String> a, List<String> b) {
    final left = a.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final right = b.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _sameInstant(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  String _uid(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'null';
    return trimmed;
  }

  String _date(DateTime? value) => value?.toIso8601String() ?? 'null';

  String _shortText(String value, {int max = 80}) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max - 1)}…';
  }
}
