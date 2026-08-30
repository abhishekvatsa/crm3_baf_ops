part of 'maintenance_provider.dart';

class FirestoreMaintenanceRepository extends MaintenanceRepository {
  final AuditRepository _auditRepo;

  FirestoreMaintenanceRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final _collection = FirebaseFirestore.instance.collection(
    'maintenance_records',
  );
  final _qualityWarnings = FirebaseFirestore.instance.collection(
    'quality_warnings',
  );
  final _directives = FirebaseFirestore.instance.collection('directives');
  final _burnerClosures = FirebaseFirestore.instance.collection(
    'maintenance_burner_closures',
  );

  Map<String, dynamic>? _sanitizeForAudit(Map<String, dynamic>? data) {
    if (data == null) return null;
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is FieldValue) {
        sanitized[key] = value.toString();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTickets() {
    return _collection
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchAllTickets({int? limit}) {
    var query = _collection
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsOverlappingPeriod(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream<List<MaintenanceRecord>>.error(
        ArgumentError('Report start must precede report end.'),
      );
    }
    // Historical maintenance rows contain client-local ISO strings, while
    // newer records may carry offset-aware instants. Firestore string ranges
    // cannot order those representations as one timeline, so reporting reads
    // the complete uncapped stream and applies the parsed overlap contract.
    return watchAllTickets().map(
      (records) => records
          .where(
            (record) => maintenanceRecordOverlapsPeriod(
              record,
              startInclusive,
              endExclusive,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsForAsset(
    AssetType type,
    int number, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('assetNumber', isEqualTo: number)
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Stream<List<MaintenanceRecord>> watchOpenTicketsByAssetType(
    AssetType type, {
    int? limit,
  }) {
    var query = _collection
        .where('assetType', isEqualTo: type.name)
        .where('isResolved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snap) => snap.docs.map(_mapTicket).toList());
  }

  @override
  Future<void> saveTicket(MaintenanceRecord record) async {
    _requireValidMaintenanceEvidence(record);
    if (record.firestoreId == null) {
      throw Exception('firestoreId cannot be null');
    }
    final ticketData = _ticketToMap(record);
    final warning = qualityWarningProjectionForIssue(record);
    final safetyDirective = burnerRedHotDirectiveProjection(record);
    if (warning == null && safetyDirective == null) {
      await _collection
          .doc(record.firestoreId)
          .set(ticketData, SetOptions(merge: true));
      return;
    }
    final warningId = warning?['warningId'] as String?;
    final warningExists =
        warningId == null
            ? false
            : (await _qualityWarnings.doc(warningId).get()).exists;
    final directiveId = safetyDirective?['firestoreId'] as String?;
    final directiveExists =
        directiveId == null
            ? false
            : (await _directives.doc(directiveId).get()).exists;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      _collection.doc(record.firestoreId),
      ticketData,
      SetOptions(merge: true),
    );
    if (warning != null && warningId != null && !warningExists) {
      batch.set(_qualityWarnings.doc(warningId), warning);
    }
    if (safetyDirective != null && directiveId != null && !directiveExists) {
      batch.set(_directives.doc(directiveId), safetyDirective);
    }
    await batch.commit();
  }

  @override
  Future<void> upsertTicket(MaintenanceRecord record) async =>
      await saveTicket(record);

  @override
  Future<List<MaintenanceRecord>> getOpenTickets() async {
    final snap =
        await _collection
            .where('isResolved', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<List<MaintenanceRecord>> getOpenTicketsByAssetType(
    AssetType type,
  ) async {
    final snap =
        await _collection
            .where('assetType', isEqualTo: type.name)
            .where('isResolved', isEqualTo: false)
            .where('isDeleted', isEqualTo: false)
            .get();
    final list = snap.docs.map(_mapTicket).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MaintenanceRecord>> getAllTickets() async {
    final snap =
        await _collection
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<PaginatedMaintenanceResult> getUpdatedTickets({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The maintenance pull has no server upper bound.',
        reasonCode: 'maintenance-server-anchor-missing',
      );
    }
    var query = globalPullServerWindowQuery(
      _collection,
      afterInclusive: since,
      throughInclusive: through,
    );
    query = query.limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.get();
    final records = <MaintenanceRecord>[];
    var decodeErrorCount = 0;
    for (final doc in snap.docs) {
      try {
        records.add(_mapTicket(doc));
      } catch (error) {
        decodeErrorCount++;
        debugPrint(
          'Rejected malformed maintenance document ${doc.id} during global '
          'pull (${error.runtimeType}).',
        );
      }
    }
    return PaginatedMaintenanceResult(
      records: records,
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      sourceDocumentCount: snap.docs.length,
      decodeErrorCount: decodeErrorCount,
    );
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsForAsset(
    AssetType type,
    int number,
  ) async {
    final snap =
        await _collection
            .where('assetType', isEqualTo: type.name)
            .where('assetNumber', isEqualTo: number)
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<MaintenanceRecord?> getTicketById(dynamic id) async {
    final doc = await _collection.doc(id as String).get();
    if (!doc.exists) return null;
    final ticket = _mapTicket(doc);
    return ticket.isDeleted ? null : ticket;
  }

  @override
  Future<void> deleteTicket(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanSoftDeleteMaintenanceTicket(actor);
    final docId = id as String;
    final doc = await _collection.doc(docId).get();
    if (!doc.exists || doc.data() == null) return;
    final current = _mapTicket(doc);
    if (current.isDeleted) return;
    _requireMaintenanceWorkflowMapAllowsAction(
      doc.data()!,
      'delete this ticket',
    );

    final beforeSnapshot = _sanitizeForAudit(doc.data());
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final now = DateTime.now().toIso8601String();
    await _collection.doc(docId).update({
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    });

    if (auditContext != null) {
      final afterSnapshot = {
        ...?beforeSnapshot,
        'isDeleted': true,
        'deletedAt': now,
        'deletedByUid': auditContext.performedByUid,
        'deletedByName': auditContext.performedByName,
        'deleteReason': auditContext.reason?.name ?? auditContext.reasonNotes,
        'updatedAt': now,
        'version': nextVersion,
      };

      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'maintenance',
            entityId: docId,
            action: AuditAction.delete,
            context: auditContext.copyWith(
              before: beforeSnapshot,
              after: afterSnapshot,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromMaintenanceRemote(
    MaintenanceRecord remote,
  ) async {
    // No-op on web. Firestore is the source of truth and is observed via
    // .snapshots() — there is no separate "local store" to tombstone.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> resolveTicket(
    dynamic id, {
    required AppUser actor,
    String? closedByUid,
    String? closedByName,
    String? remarks,
    double? downtimeHours,
    DateTime? endDate,
    List<String>? teamsInvolved,
    List<ComponentAction>? actions,
    BurnerLockoutResolution? burnerResolution,
  }) async {
    _requireCanAttemptCloseMaintenanceTicket(actor);
    final docId = id as String;
    final current = await _collection.doc(docId).get();
    if (!current.exists || current.data() == null) {
      throw StateError('Ticket not found.');
    }
    _requireMaintenanceWorkflowMapAllowsAction(
      current.data()!,
      'resolve this ticket',
    );
    final ticket = _mapTicket(current);
    _requireCanCloseMaintenanceTicket(actor, ticket);
    _requireValidMaintenanceEvidence(ticket);
    final lockout = ticket.burnerLockoutCase;
    if (lockout != null) {
      if (burnerResolution == null) {
        throw StateError(
          'Every affected burner needs a terminal outcome before closure.',
        );
      }
      validateBurnerResolutionEvidence(
        lockout: lockout,
        resolution: burnerResolution,
        actions: actions ?? const <ComponentAction>[],
      );
    } else if (burnerResolution != null) {
      throw StateError(
        'Burner outcomes cannot be attached to a standard issue.',
      );
    }
    final now = (endDate ?? DateTime.now()).toIso8601String();
    final updatedAt = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'isResolved': true,
      'status': TicketStatus.resolved.name,
      'endDate': now,
      'closedByUid': closedByUid,
      'closedByName': closedByName,
      'remarks': remarks,
      'downtimeHours': downtimeHours,
      'teamsInvolved': <String>{
        ...ticket.issueLanePlan.assignedLanes,
        ...?teamsInvolved,
      }.toList(growable: false),
      ...ticket.issueLanePlan.completeAll().toSynchronizedFields(),
      if (ticket.acknowledgedByUid == null)
        'acknowledgedByUid': closedByUid ?? actor.uid,
      if (ticket.acknowledgedByUid == null)
        'acknowledgedByName':
            closedByName ?? (actor.name.isNotEmpty ? actor.name : actor.uid),
      if (ticket.acknowledgedByUid == null) 'acknowledgedAt': now,
      'updatedAt': updatedAt,
      'version': ticket.version + 1,
    };
    if (actions != null && actions.isNotEmpty) {
      updateData['actionsJson'] = ComponentAction.encode(actions);
    }
    if (lockout != null && burnerResolution != null) {
      updateData.addAll(
        lockout
            .withResolution(
              burnerResolution,
              actions: actions ?? const <ComponentAction>[],
            )
            .toSynchronizedFields(),
      );
    }
    final burnerClosure = burnerClosureEvidenceProjectionForIssueMap(
      updateData,
      docId,
    );
    if (burnerClosure == null) {
      await _collection.doc(docId).update(updateData);
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_collection.doc(docId), updateData);
    batch.set(_burnerClosures.doc(docId), burnerClosure);
    await batch.commit();
  }

  @override
  Future<void> reopenTicket(
    dynamic id, {
    required AppUser actor,
    required String reopenedByUid,
    required String reopenedByName,
    String? reopenRemarks,
  }) async {
    final reopen = _validatedMaintenanceReopenEvidence(
      actor: actor,
      reopenedByUid: reopenedByUid,
      reopenedByName: reopenedByName,
      reopenRemarks: reopenRemarks,
    );
    final docId = id as String;
    final doc = await _collection.doc(docId).get();
    if (!doc.exists || doc.data() == null) throw Exception('Ticket not found');
    final data = doc.data()!;
    _requireMaintenanceWorkflowMapAllowsAction(data, 'reopen this ticket');
    final current = _mapTicket(doc);
    _requireValidMaintenanceEvidence(current);
    final closedAt = current.endDate;
    if (!current.isResolved || closedAt == null) {
      throw Exception('Ticket is not resolved or has no end date');
    }
    if (DateTime.now().difference(closedAt).inHours > 4) {
      throw Exception('Cannot reopen: closed more than 4 hours ago');
    }
    final reopenedAt = DateTime.now().toUtc();

    final currentHistory = data['resolutionHistoryJson'];
    if (currentHistory is! String || currentHistory.trim().isEmpty) {
      throw const FormatException(
        'Ticket resolution history is absent or is not serialized JSON.',
      );
    }
    final historyPayload = readValidatedResolutionHistoryPayload(
      currentHistory,
      source: 'maintenance/$docId',
    );
    historyPayload.rows.add(
      ResolutionHistory.fromMap({
        'resolvedByUid': data['closedByUid'],
        'resolvedByName': data['closedByName'],
        'resolvedAt': closedAt,
        'actionsJson': data['actionsJson'] ?? '[]',
        'remarks': data['remarks'],
        'downtimeHours': data['downtimeHours'],
        'teamsInvolved': data['teamsInvolved'] ?? const <String>[],
        'reopenedByUid': reopen.uid,
        'reopenedByName': reopen.name,
        'reopenedAt': reopenedAt,
        'reopenReason': reopen.reason,
      }, source: 'maintenance/$docId current closure').toMap(),
    );
    final newHistoryJson = jsonEncode(historyPayload.rows);
    final burnerLockout = current.burnerLockoutCase;
    final reopenedLanePlan = current.issueLanePlan.reopen();

    await _collection.doc(docId).update({
      'isResolved': false,
      'status': TicketStatus.open.name,
      ...reopenedLanePlan.toSynchronizedFields(),
      'acknowledgedByUid': null,
      'acknowledgedByName': null,
      'acknowledgedAt': null,
      'endDate': FieldValue.delete(),
      'closedByUid': FieldValue.delete(),
      'closedByName': FieldValue.delete(),
      'downtimeHours': FieldValue.delete(),
      'actionsJson': '[]',
      if (burnerLockout != null) 'burnerAttendedPositions': <int>[],
      if (burnerLockout != null)
        'burnerResolutionEvidence': <String, dynamic>{},
      'reopenedByUid': reopen.uid,
      'reopenedByName': reopen.name,
      'reopenedAt': reopenedAt.toIso8601String(),
      'reopenReason': reopen.reason,
      'remarks': reopen.reason,
      'teamsInvolved': [],
      'resolutionHistoryJson': newHistoryJson,
      'updatedAt': reopenedAt.toIso8601String(),
      'updatedByUid': reopen.uid,
      'updatedByName': reopen.name,
      'version': FieldValue.increment(1),
    });
  }

  @override
  Future<List<MaintenanceRecord>> getClosedTickets({
    int limit = 50,
    int offset = 0,
    DocumentSnapshot? lastDocument,
  }) async {
    var query = _collection
        .where('isResolved', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('endDate', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return snap.docs.map(_mapTicket).toList();
  }

  @override
  Future<ClosedTicketPage> getClosedTicketPage({
    int limit = 50,
    int offset = 0,
    ClosedTicketPageCursor? cursor,
  }) async {
    var query = _collection
        .where('isResolved', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('endDate', descending: true)
        .limit(limit);
    if (cursor is _FirestoreClosedTicketPageCursor) {
      query = query.startAfterDocument(cursor.snapshot);
    }
    final snap = await query.get();
    return ClosedTicketPage(
      records: snap.docs.map(_mapTicket).toList(growable: false),
      cursor:
          snap.docs.isEmpty
              ? null
              : _FirestoreClosedTicketPageCursor(snap.docs.last),
    );
  }

  @override
  Future<int> getClosedTicketsCount() async {
    final snap =
        await _collection
            .where('isResolved', isEqualTo: true)
            .where('isDeleted', isEqualTo: false)
            .count()
            .get();
    return snap.count ?? 0;
  }

  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async => [];
  @override
  Future<void> markTicketSynced(dynamic id, String firestoreId) async {}
  @override
  Future<void> insertFromRemote(MaintenanceRecord remote) async {}
  @override
  Future<void> updateFromRemote(MaintenanceRecord remote) async {}

  @override
  Future<bool> applyMaintenanceIssueCommandReadback({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    return remote.firestoreId?.trim().isNotEmpty == true && !remote.isDeleted;
  }

  @override
  Future<bool> applyMaintenanceIssueServerRefresh({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    return remote.firestoreId?.trim().isNotEmpty == true;
  }

  @override
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId) async {
    final doc = await _collection.doc(firestoreId).get();
    return doc.exists ? _mapTicket(doc) : null;
  }

  @override
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  ) async {
    final doc = await _collection
        .doc(firestoreId)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? _mapTicket(doc) : null;
  }

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <MaintenanceRecord>[];
    for (var i = 0; i < firestoreIds.length; i += 30) {
      final chunk = firestoreIds.sublist(
        i,
        i + 30 > firestoreIds.length ? firestoreIds.length : i + 30,
      );
      final snap =
          await _collection.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_mapTicket));
    }
    return results;
  }

  @override
  Future<void> batchUpsertTickets(List<MaintenanceRecord> records) async {
    if (records.length > maintenancePairedBatchMaximum) {
      throw ArgumentError.value(
        records.length,
        'records.length',
        'A paired maintenance batch cannot exceed '
            '$maintenancePairedBatchMaximum records.',
      );
    }
    if (records.isEmpty) return;
    final warnings = <String, Map<String, dynamic>>{};
    final directives = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final warning = qualityWarningProjectionForIssue(record);
      if (warning != null) {
        warnings[warning['warningId'] as String] = warning;
      }
      final directive = burnerRedHotDirectiveProjection(record);
      if (directive != null) {
        directives[directive['firestoreId'] as String] = directive;
      }
    }
    final existingWarningIds = await _existingQualityWarningIds(warnings.keys);
    final existingDirectiveIds = await _existingDirectiveIds(directives.keys);
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _collection.doc(record.firestoreId),
          _ticketToMap(record),
          SetOptions(merge: true),
        );
      }
    }
    for (final entry in warnings.entries) {
      if (!existingWarningIds.contains(entry.key)) {
        batch.set(_qualityWarnings.doc(entry.key), entry.value);
      }
    }
    for (final entry in directives.entries) {
      if (!existingDirectiveIds.contains(entry.key)) {
        batch.set(_directives.doc(entry.key), entry.value);
      }
    }
    await batch.commit();
  }

  @override
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    final id = _cleanOptionalMaintenanceText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteMaintenanceLifecycleReplayStepForSync requires a non-empty firestoreId',
      );
    }

    // Field-scoped merge: the caller provides only the fields for one
    // maintenance lifecycle rule branch. This avoids pushing a collapsed final
    // dirty snapshot that skips the server-visible open/closed/open sequence.
    final warning = qualityWarningProjectionForIssueMap(stepData, id);
    final safetyDirective = burnerRedHotDirectiveProjectionForIssueMap(
      stepData,
      id,
    );
    final burnerClosure = burnerClosureEvidenceProjectionForIssueMap(
      stepData,
      id,
    );
    if (warning == null && safetyDirective == null && burnerClosure == null) {
      await _collection.doc(id).set(stepData, SetOptions(merge: true));
      return;
    }
    final warningId = warning?['warningId'] as String?;
    final warningExists =
        warningId == null
            ? false
            : (await _qualityWarnings.doc(warningId).get()).exists;
    final directiveId = safetyDirective?['firestoreId'] as String?;
    final directiveRef =
        directiveId == null ? null : _directives.doc(directiveId);
    final directiveExists =
        directiveRef == null ? false : (await directiveRef.get()).exists;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_collection.doc(id), stepData, SetOptions(merge: true));
    if (warning != null && warningId != null && !warningExists) {
      batch.set(_qualityWarnings.doc(warningId), warning);
    }
    if (safetyDirective != null && directiveRef != null && !directiveExists) {
      batch.set(directiveRef, safetyDirective);
    }
    if (burnerClosure != null) {
      batch.set(_burnerClosures.doc(id), burnerClosure);
    }
    await batch.commit();
  }

  @override
  Future<Map<String, dynamic>?>
  readRemoteMaintenanceLifecycleReplayFieldsForSync(String firestoreId) async {
    final id = _cleanOptionalMaintenanceText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'readRemoteMaintenanceLifecycleReplayFieldsForSync requires a '
        'non-empty firestoreId',
      );
    }
    final document = await _collection
        .doc(id)
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    return document.exists && data != null
        ? Map<String, dynamic>.from(data)
        : null;
  }

  @override
  Future<bool> applyGovernedCreationServerStateForSync({
    required MaintenanceRecord remote,
    required SyncPushSnapshot expectedLocal,
  }) {
    throw UnsupportedError(
      'applyGovernedCreationServerStateForSync is a local sync primitive and '
      'is not supported by the Firestore maintenance repository.',
    );
  }

  @override
  Future<bool> applyMaintenanceLifecycleReplayReceiptForSync({
    required MaintenanceRecord remote,
    required SyncPushSnapshot expectedLocal,
  }) {
    throw UnsupportedError(
      'applyMaintenanceLifecycleReplayReceiptForSync is a local sync '
      'primitive and is not supported by the Firestore maintenance repository.',
    );
  }

  Future<Set<String>> _existingQualityWarningIds(
    Iterable<String> warningIds,
  ) async {
    final ids = warningIds.toSet().toList();
    final existing = <String>{};
    for (var index = 0; index < ids.length; index += 30) {
      final chunk = ids.sublist(
        index,
        index + 30 > ids.length ? ids.length : index + 30,
      );
      if (chunk.isEmpty) continue;
      final snapshot =
          await _qualityWarnings
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      existing.addAll(snapshot.docs.map((document) => document.id));
    }
    return existing;
  }

  Future<Set<String>> _existingDirectiveIds(
    Iterable<String> directiveIds,
  ) async {
    final ids = directiveIds.toSet().toList();
    final existing = <String>{};
    for (var index = 0; index < ids.length; index += 30) {
      final chunk = ids.sublist(
        index,
        index + 30 > ids.length ? ids.length : index + 30,
      );
      if (chunk.isEmpty) continue;
      final snapshot =
          await _directives.where(FieldPath.documentId, whereIn: chunk).get();
      existing.addAll(snapshot.docs.map((document) => document.id));
    }
    return existing;
  }

  @override
  Future<void> markTicketsSynced(List<int> ids) async {}

  @override
  Future<void> markTicketsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  // 🔥 FULL MAPPING (RESTORED)
  Map<String, dynamic> _ticketToMap(MaintenanceRecord t) => {
    ...t.qualityIntentSynchronizedFields,
    ...t.burnerLockoutSynchronizedFields,
    ...t.issueLaneSynchronizedFields,
    ...t.administrativeClosureSynchronizedFields,
    'firestoreId': t.firestoreId,
    'version': t.version,
    'assetType': t.assetType.name,
    'assetNumber': t.assetNumber,
    'component': t.component,
    'subsystem': t.subsystem,
    'tag': t.tag,
    'hierarchyPath': t.hierarchyPath,
    'assetHierarchyRefJson': t.assetHierarchyRefJson,
    'maintenanceType': t.maintenanceType.name,
    'classification': t.classification,
    'description': t.description,
    if (t.plantConditionEffect != MaintenanceIssuePlantConditionEffect.none)
      'plantConditionEffect': t.plantConditionEffect.name,
    'routedTo': t.routedTo.name,
    'otherDepartment': t.otherDepartment,
    'status': t.status.name,
    'isResolved': t.isResolved,
    'isCritical': t.isCritical,
    'loggedByUid': t.loggedByUid,
    'loggedByName': t.loggedByName,
    'reportedBy': t.reportedBy,
    'acknowledgedByUid': t.acknowledgedByUid,
    'acknowledgedByName': t.acknowledgedByName,
    'acknowledgedAt': t.acknowledgedAt?.toIso8601String(),
    'closedByUid': t.closedByUid,
    'closedByName': t.closedByName,
    'reopenedByUid': t.reopenedByUid,
    'reopenedByName': t.reopenedByName,
    'reopenedAt': t.reopenedAt?.toIso8601String(),
    'reopenReason': t.reopenReason,
    'teamsInvolved': t.teamsInvolved,
    'performedBy': t.performedBy,
    'remarks': t.remarks,
    'startDate': t.startDate.toIso8601String(),
    'endDate': t.endDate?.toIso8601String(),
    'downtimeHours': t.downtimeHours,
    'chargeNoAtEvent': t.chargeNoAtEvent,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'metadataJson': t.metadataJson,
    'actionsJson': t.actionsJson,
    'resolutionHistoryJson': t.resolutionHistoryJson,
    'isDeleted': t.isDeleted,
    'deletedAt': t.deletedAt?.toIso8601String(),
    'deletedByUid': t.deletedByUid,
    'deletedByName': t.deletedByName,
    'deleteReason': t.deleteReason,
  };

  MaintenanceRecord _mapTicket(DocumentSnapshot doc) {
    return readRemoteMaintenanceRecord(
      Map<String, dynamic>.from(doc.data() as Map),
      documentId: doc.id,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS (REACTIVE MIGRATION)
// ─────────────────────────────────────────────────────────────
