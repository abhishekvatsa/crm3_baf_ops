part of 'operational_directive_provider.dart';

class FirestoreDirectiveRepository implements DirectiveRepository {
  final AuditRepository _auditRepo;

  FirestoreDirectiveRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final _col = FirebaseFirestore.instance.collection('directives');

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
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    var query = _col
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => _mapDirective(doc)).toList(),
    );
  }

  @override
  Stream<List<OperationalDirective>> watchOpenDirectives() {
    return _col
        .where(
          'status',
          whereIn: [
            DirectiveStatus.open.name,
            DirectiveStatus.acknowledged.name,
          ],
        )
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => _mapDirective(doc)).toList());
  }

  @override
  Future<void> saveDirective(
    OperationalDirective d, {
    required AppUser actor,
  }) async {
    if (d.firestoreId == null) {
      throw Exception('firestoreId required');
    }
    _requireCanCreateDirective(actor, d);
    _normalizeDirectiveForLocalWrite(
      d,
      bumpVersion: false,
      markUnsynced: false,
    );
    d.isSynced = true;
    await _col
        .doc(d.firestoreId)
        .set(_directiveToMap(d), SetOptions(merge: true));
  }

  @override
  Future<List<OperationalDirective>> getOpenDirectives() async {
    final snap =
        await _col
            .where(
              'status',
              whereIn: [
                DirectiveStatus.open.name,
                DirectiveStatus.acknowledged.name,
              ],
            )
            .where('isDeleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
    return snap.docs.map((doc) => _mapDirective(doc)).toList();
  }

  @override
  Future<List<OperationalDirective>> getAllDirectives() async {
    final snap = await _col.where('isDeleted', isEqualTo: false).get();
    return snap.docs.map((doc) => _mapDirective(doc)).toList();
  }

  @override
  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The directive pull has no server upper bound.',
        reasonCode: 'directive-server-anchor-missing',
      );
    }
    var query = globalPullServerWindowQuery(
      _col,
      afterInclusive: since,
      throughInclusive: through,
    );

    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) {
      return PaginatedDirectivesResult(records: [], lastDoc: null);
    }

    return PaginatedDirectivesResult(
      records: snap.docs.map((doc) => _mapDirective(doc)).toList(),
      lastDoc: snap.docs.last,
    );
  }

  @override
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    if (directive.firestoreId == null) return;
    _requireCanAdminMutateDirective(actor, 'edit');
    _normalizeDirectiveForLocalWrite(
      directive,
      bumpVersion: false,
      markUnsynced: false,
    );
    directive.isSynced = true;
    final updateMap = <String, dynamic>{
      'title': directive.title,
      'description': directive.description,
      'directedTo': directive.directedTo.name,
      'assetType': directive.assetType?.name,
      'assetNumber': directive.assetNumber,
      'component': directive.component,
      'subsystem': directive.subsystem,
      'tag': directive.tag,
      'hierarchyPath': directive.hierarchyPath,
      'priority': directive.priority.name,
      'status': directive.status.name,
      'isActive': directive.isActive,
      'createdByUid': directive.createdByUid,
      'createdByName': directive.createdByName,
      'issuedByUid': directive.issuedByUid,
      'issuedByName': directive.issuedByName,
      'issuedAt': directive.issuedAt?.toIso8601String(),
      'acknowledgedByUid': directive.acknowledgedByUid,
      'acknowledgedByName': directive.acknowledgedByName,
      'acknowledgedAt': directive.acknowledgedAt?.toIso8601String(),
      'closedByUid': directive.closedByUid,
      'closedByName': directive.closedByName,
      'closedAt': directive.closedAt?.toIso8601String(),
      'closedWithoutAcknowledgement': directive.closedWithoutAcknowledgement,
      'remarks': directive.remarks,
      'linkedMaintenanceFirestoreId': directive.linkedMaintenanceFirestoreId,
      'linkedExecutionFirestoreId': directive.linkedExecutionFirestoreId,
      'metadataJson': directive.metadataJson,
      'updatedAt': directive.updatedAt.toIso8601String(),
      'version': FieldValue.increment(1),
    };
    await _col.doc(directive.firestoreId!).update(updateMap);
  }

  @override
  Future<void> deleteDirective(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanAdminMutateDirective(actor, 'delete');
    final docId = id as String;

    final beforeDoc = await _col.doc(docId).get();

    Map<String, dynamic>? beforeSnapshot;
    if (beforeDoc.exists) {
      beforeSnapshot = _sanitizeForAudit(beforeDoc.data());
    }

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    await _col.doc(docId).update({
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    });

    final afterSnapshot = {
      ...?beforeSnapshot,
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
    };

    if (auditContext != null) {
      final auditRepo = _auditRepo;
      unawaited(
        auditRepo.log(
          AuditEvent.fromContext(
            entityType: 'directive',
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
  Future<RemoteTombstoneApplyResult> applyTombstoneFromDirectiveRemote(
    OperationalDirective remote,
  ) async {
    // No-op on web.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> acknowledgeDirective(
    dynamic id, {
    required AppUser actor,
  }) async {
    final firestoreId = id as String;
    final current = await getByFirestoreId(firestoreId);
    if (current == null) {
      throw StateError('Directive not found.');
    }
    _requireCanAcknowledgeDirective(actor, current);

    final now = DateTime.now().toIso8601String();
    await _col.doc(firestoreId).update({
      'status': DirectiveStatus.acknowledged.name,
      'isActive': true,
      'acknowledgedByUid': actor.uid,
      'acknowledgedByName': actor.name,
      'acknowledgedAt': now,
      'closedByUid': null,
      'closedByName': null,
      'closedAt': null,
      'closedWithoutAcknowledgement': false,
      'updatedAt': now,
      'version': FieldValue.increment(1),
    });
  }

  @override
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    bool wasUnacknowledged = false,
  }) async {
    final firestoreId = id as String;
    final current = await getByFirestoreId(firestoreId);
    if (current == null) {
      throw StateError('Directive not found.');
    }
    _requireCanCloseDirective(actor, current);

    final now = DateTime.now().toIso8601String();
    final cleanedRemarks = _cleanOptionalDirectiveText(remarks);
    final updateMap = <String, dynamic>{
      'status': DirectiveStatus.closed.name,
      'isActive': false,
      'closedByUid': actor.uid,
      'closedByName': actor.name,
      'closedAt': now,
      'closedWithoutAcknowledgement': wasUnacknowledged,
      'updatedAt': now,
      'version': FieldValue.increment(1),
    };
    if (cleanedRemarks != null) {
      updateMap['remarks'] = cleanedRemarks;
    }
    await _col.doc(firestoreId).update(updateMap);
  }

  @override
  Future<void> adoptServerDirectiveClosure({
    required String firestoreId,
    required int expectedBeforeVersion,
    required int committedVersion,
    required AppUser actor,
    required DateTime closedAt,
    required bool wasUnacknowledged,
    String? remarks,
  }) async {
    final current = await getByFirestoreId(firestoreId);
    if (current == null ||
        !current.isClosed ||
        current.isActive ||
        current.version != committedVersion ||
        current.closedByUid != actor.uid ||
        current.closedAt?.toUtc() != closedAt.toUtc() ||
        current.closedWithoutAcknowledgement != wasUnacknowledged ||
        (remarks != null && current.remarks != remarks.trim())) {
      throw StateError(
        'The server directive closure could not be read back exactly.',
      );
    }
  }

  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async => [];

  @override
  Future<void> markDirectiveSynced(dynamic id, String firestoreId) async {}

  @override
  Future<OperationalDirective?> getByFirestoreId(String firestoreId) async {
    final doc = await _col.doc(firestoreId).get();
    if (!doc.exists) return null;
    return _mapDirective(doc);
  }

  @override
  Future<void> insertFromRemote(OperationalDirective remote) async {}

  @override
  Future<void> updateFromRemote(OperationalDirective remote) async {}

  @override
  Future<List<OperationalDirective>> getDirectivesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <OperationalDirective>[];
    for (var i = 0; i < firestoreIds.length; i += 30) {
      final chunk = firestoreIds.sublist(
        i,
        i + 30 > firestoreIds.length ? firestoreIds.length : i + 30,
      );
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_mapDirective));
    }
    return results;
  }

  @override
  Future<void> batchUpsertDirectives(List<OperationalDirective> records) async {
    if (records.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _col.doc(record.firestoreId),
          _directiveToMap(record),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<void> markDirectivesSynced(List<int> ids) async {}

  @override
  Future<void> markDirectivesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  // ── Mapping helpers ─────────────────────────────────────────
  Map<String, dynamic> _directiveToMap(OperationalDirective d) {
    _normalizeDirectiveIdentity(d);
    _normalizeDirectiveTextFields(d);
    _normalizeDirectiveLifecycle(d);
    final firestoreId = _cleanOptionalDirectiveText(d.firestoreId);
    if (firestoreId == null) {
      throw StateError('Directive firestoreId is required for persistence.');
    }
    d.firestoreId = firestoreId;
    return d.toMap();
  }

  OperationalDirective _mapDirective(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return readRemoteOperationalDirective(data, documentId: doc.id);
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
