part of 'operational_directive_provider.dart';

class FirestoreDirectiveRepository implements DirectiveRepository {
  final OrdinaryDirectiveCommands _ordinary;

  FirestoreDirectiveRepository({
    AuditRepository? auditRepository,
    OrdinaryDirectiveCommands? ordinaryCommands,
  }) : _ordinary = ordinaryCommands ?? OrdinaryDirectiveCommands(web: true);

  final _col = FirebaseFirestore.instance.collection('directives');

  @override
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    var query = _col
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snap) => _decodeDirectiveSnapshot(snap, source: 'all directives'),
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
        .map(
          (snap) => _decodeDirectiveSnapshot(snap, source: 'open directives'),
        );
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
    if (!isGovernedBurnerRoundDirectiveId(d.firestoreId)) {
      await _ordinary.save(
        actor: actor,
        action: 'create',
        after: d,
        reason: 'Issue the reviewed instruction.',
      );
      return;
    }
    d.isSynced = true;
    await _col
        .doc(d.firestoreId)
        .set(_directiveToMap(d), SetOptions(merge: true));
  }

  @override
  Future<List<OperationalDirective>> getOpenDirectives() async {
    final snap = await _col
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
    return _decodeDirectiveSnapshot(snap, source: 'open directives');
  }

  @override
  Future<List<OperationalDirective>> getAllDirectives() async {
    final snap = await _col.where('isDeleted', isEqualTo: false).get();
    return _decodeDirectiveSnapshot(snap, source: 'all directives');
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

    final snap = await query.get(authoritativeGlobalPullReadOptions);
    if (snap.docs.isEmpty) {
      return PaginatedDirectivesResult(records: [], lastDoc: null);
    }

    final batch = decodeSnapshotBatch(
      snap,
      (data, id) => readRemoteOperationalDirective(data, documentId: id),
      source: 'directive pull',
    );
    return PaginatedDirectivesResult(
      records: batch.records,
      lastDoc: snap.docs.last,
      rejectedIds: batch.rejectedDocumentIds,
      rawCount: snap.docs.length,
    );
  }

  @override
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    final current = await getByFirestoreId(directive.firestoreId!);
    if (current == null) throw StateError('Directive not found.');
    if (!isGovernedBurnerRoundDirectiveId(current.firestoreId)) {
      if (current.version != directive.version) {
        throw StateError(
          'The directive changed; keep your draft and review the current instruction.',
        );
      }
      final reason = directive.amendmentReason ?? '';
      final after = _ordinaryChange(
        current,
        actor,
        'amend',
        reason: reason,
        draft: directive,
      );
      await _ordinary.save(
        actor: actor,
        action: 'amend',
        before: current,
        after: after,
        reason: reason,
      );
      return;
    }

    if (directive.firestoreId == null) return;
    throw StateError(
      'This automatic Burner/UV instruction must use its governed workflow; ordinary editing or deletion is not permitted.',
    );
  }

  @override
  Future<void> deleteDirective(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final current = await getByFirestoreId(id as String);
    if (current == null) throw StateError('Directive not found.');
    if (!isGovernedBurnerRoundDirectiveId(current.firestoreId)) {
      if (auditContext?.performedByUid != actor.uid ||
          auditContext?.before?['version'] != current.version) {
        throw StateError(
          'The directive changed. Review it again before deletion.',
        );
      }
      final reason = auditContext?.reasonNotes?.trim().isNotEmpty == true
          ? auditContext!.reasonNotes!
          : auditContext?.reason?.name ?? '';
      final after = _ordinaryChange(current, actor, 'delete', reason: reason);
      await _ordinary.save(
        actor: actor,
        action: 'delete',
        before: current,
        after: after,
        reason: reason,
      );
      return;
    }

    throw StateError(
      'This automatic Burner/UV instruction must use its governed workflow; ordinary editing or deletion is not permitted.',
    );
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
    required int expectedVersion,
  }) async {
    final current = await getByFirestoreId(id as String);
    if (current == null) throw StateError('Directive not found.');
    if (!isGovernedBurnerRoundDirectiveId(current.firestoreId)) {
      if (current.version != expectedVersion) {
        throw StateError(
          'The directive changed; keep your draft and review the current instruction.',
        );
      }
      const reason = 'Received the reviewed instruction.';
      final after = _ordinaryChange(
        current,
        actor,
        'acknowledge',
        reason: reason,
      );
      await _ordinary.save(
        actor: actor,
        action: 'acknowledge',
        before: current,
        after: after,
        reason: reason,
      );
      return;
    }

    final firestoreId = id;
    final reference = _col.doc(firestoreId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Directive not found.');
      final current = _mapDirective(snapshot);
      _requireCanAcknowledgeDirective(actor, current);
      if (current.version != expectedVersion) {
        throw StateError(
          'The directive changed while acknowledgement was being reviewed. Refresh before acknowledging.',
        );
      }

      final now = DateTime.now().toIso8601String();
      transaction.update(reference, {
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
    });
  }

  @override
  Future<void> closeDirective(
    dynamic id, {
    required AppUser actor,
    required int expectedVersion,
    String? remarks,
    bool wasUnacknowledged = false,
  }) async {
    final current = await getByFirestoreId(id as String);
    if (current == null) throw StateError('Directive not found.');
    if (!isGovernedBurnerRoundDirectiveId(current.firestoreId)) {
      if (current.version != expectedVersion) {
        throw StateError(
          'The directive changed; keep your draft and review the current instruction.',
        );
      }
      final reason = remarks?.trim().isNotEmpty == true
          ? remarks!.trim()
          : 'Close the reviewed instruction.';
      final after = _ordinaryChange(current, actor, 'close', reason: reason);
      await _ordinary.save(
        actor: actor,
        action: 'close',
        before: current,
        after: after,
        reason: reason,
      );
      return;
    }

    final firestoreId = id;
    final reference = _col.doc(firestoreId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Directive not found.');
      final current = _mapDirective(snapshot);
      _requireCanCloseDirective(actor, current);
      if (current.version != expectedVersion) {
        throw StateError(
          'The directive changed while closure was being reviewed. Refresh before closing.',
        );
      }
      final expectedWithoutAcknowledgement =
          current.acknowledgedAt == null && current.acknowledgedByUid == null;
      if (wasUnacknowledged != expectedWithoutAcknowledgement) {
        throw StateError(
          'The directive acknowledgement changed while closure was being reviewed.',
        );
      }

      final now = DateTime.now().toIso8601String();
      final cleanedRemarks = _cleanOptionalDirectiveText(remarks);
      final updateMap = <String, dynamic>{
        'status': DirectiveStatus.closed.name,
        'isActive': false,
        'closedByUid': actor.uid,
        'closedByName': actor.name,
        'closedAt': now,
        'closedWithoutAcknowledgement': expectedWithoutAcknowledgement,
        'updatedAt': now,
        'version': FieldValue.increment(1),
      };
      if (cleanedRemarks != null) updateMap['remarks'] = cleanedRemarks;
      transaction.update(reference, updateMap);
    });
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
  Future<RemoteRecordApplyResult<OperationalDirective>>
  applyDirectiveFromRemote(OperationalDirective remote) {
    throw UnsupportedError(
      'Firestore cannot apply a remote directive to itself.',
    );
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
      results.addAll(
        _decodeAuthoritativeDirectiveSnapshot(snap, source: 'directive lookup'),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertDirectives(List<OperationalDirective> records) async {
    if (records.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    var ordinaryWrites = 0;
    for (final record in records) {
      if (isGovernedBurnerRoundDirectiveId(record.firestoreId)) {
        final local = copyOperationalDirective(record);
        final reference = _col.doc(local.firestoreId!);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(reference);
          if (!snapshot.exists) {
            throw StateError('The server burner directive no longer exists.');
          }
          final patch = governedDirectiveAcknowledgementPatch(
            local: local,
            remote: _mapDirective(snapshot),
          );
          if (patch.isNotEmpty) transaction.update(reference, patch);
        });
        continue;
      }
      if (record.firestoreId != null) {
        batch.set(
          _col.doc(record.firestoreId),
          _directiveToMap(record),
          SetOptions(merge: true),
        );
        ordinaryWrites++;
      }
    }
    if (ordinaryWrites > 0) await batch.commit();
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

  List<OperationalDirective> _decodeDirectiveSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String source,
  }) => DirectivePopulation(
    decodeSnapshotBatch(
      snapshot,
      (data, id) => readRemoteOperationalDirective(data, documentId: id),
      source: source,
    ),
  );

  List<OperationalDirective> _decodeAuthoritativeDirectiveSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String source,
  }) {
    final batch = decodeSnapshotBatch(
      snapshot,
      (data, documentId) =>
          readRemoteOperationalDirective(data, documentId: documentId),
      source: source,
    );
    if (!batch.isComplete) {
      throw StateError(
        'The authoritative $source is incomplete; refused to advance or '
        'reconcile past malformed directive documents: '
        '${batch.rejectedDocumentIds.join(', ')}',
      );
    }
    return batch.records;
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
