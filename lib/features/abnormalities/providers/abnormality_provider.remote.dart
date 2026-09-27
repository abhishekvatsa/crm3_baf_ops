part of 'abnormality_provider.dart';

class FirestoreAbnormalityRepository implements AbnormalityRepository {
  static const _uuid = Uuid();

  final AuditRepository _auditRepo;
  final OnlineRetainedRowMutations _retainedMutations;
  final fs.FirebaseFirestore _firestore;

  FirestoreAbnormalityRepository({
    AuditRepository? auditRepository,
    fs.FirebaseFirestore? firestore,
    OnlineRetainedRowMutations? retainedMutations,
  }) : _auditRepo = auditRepository ?? AuditRepository(),
       _firestore = firestore ?? fs.FirebaseFirestore.instance,
       _retainedMutations = retainedMutations ?? OnlineRetainedRowMutations();

  late final _types = _firestore.collection('abnormality_types');
  late final _abnormalities = _firestore.collection('charge_abnormalities');

  Future<AbnormalityType?> _readTypeForMutation(String id) async {
    final doc = await _types
        .doc(id)
        .get(const fs.GetOptions(source: fs.Source.server));
    return doc.exists ? AbnormalityType.fromMap(doc.data()!, doc.id) : null;
  }

  // ───────────────────────────────────────────────────────────
  // TYPE MASTER DATA
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<AbnormalityType>> watchActiveTypes() {
    return _types
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final records = decodeSnapshotDocuments(
            snapshot,
            AbnormalityType.fromMap,
            source: 'AbnormalityType',
          ).toList();

          records.sort(_sortTypes);
          return records;
        });
  }

  @override
  Stream<List<AbnormalityType>> watchAllTypes() {
    return _types.where('isDeleted', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      final records = decodeSnapshotDocuments(
        snapshot,
        AbnormalityType.fromMap,
        source: 'AbnormalityType',
      ).toList();

      records.sort(_sortTypes);
      return records;
    });
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async {
    final snapshot = await _types
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .get();

    final records = snapshot.docs
        .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
        .toList();

    records.sort(_sortTypes);
    return records;
  }

  @override
  Future<List<AbnormalityType>> getAllTypes() async {
    final snapshot = await _types.where('isDeleted', isEqualTo: false).get();

    final records = snapshot.docs
        .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
        .toList();

    records.sort(_sortTypes);
    return records;
  }

  @override
  Future<AbnormalityType?> getTypeById(dynamic id) async {
    return getTypeByFirestoreId(id as String);
  }

  @override
  Future<AbnormalityType?> getTypeByFirestoreId(String firestoreId) async {
    final doc = await _types.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;

    final type = AbnormalityType.fromMap(doc.data()!, doc.id);
    if (type.isDeleted) return null;

    return type;
  }

  @override
  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);

    type.firestoreId ??= _uuid.v4();

    final before = await _readTypeForMutation(type.firestoreId!);
    final beforeSnapshot = before?.toAuditMap();
    final isCreate = before == null;
    await _retainedMutations.save(
      kind: RetainedRowKind.abnormalityType,
      actor: actor,
      record: type,
      readRemote: () => _readTypeForMutation(type.firestoreId!),
      normalize: (existing) {
        _validateTypeForSave(type, existing: existing as AbnormalityType?);
        if (existing == null) {
          type.createdByUid = actor.uid;
          type.createdByName = actor.name;
        }
        type.lastEditedByUid = actor.uid;
        type.lastEditedByName = actor.name;
        type.updatedAt = DateTime.now().toUtc();
      },
    );

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId!,
        action: isCreate ? AuditAction.create : AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: type.toAuditMap(),
      );
    }
  }

  @override
  Future<void> updateType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) => saveType(type, actor: actor, auditContext: auditContext);

  @override
  Future<void> softDeleteType(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    final docId = id as String;
    final type = await _readTypeForMutation(docId);
    if (type == null) return;
    final before = type.toAuditMap();
    await _retainedMutations.save(
      kind: RetainedRowKind.abnormalityType,
      actor: actor,
      record: type,
      readRemote: () => _readTypeForMutation(docId),
      normalize: (existing) {
        type.softDelete(
          deletedByUid: actor.uid,
          deletedByName: actor.name,
          reason: auditContext?.reason?.name ?? auditContext?.reasonNotes,
        );
        _validateTypeForSave(type, existing: existing as AbnormalityType?);
      },
    );
    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: docId,
        action: AuditAction.delete,
        context: auditContext,
        before: before,
        after: type.toAuditMap(),
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromTypeRemote(
    AbnormalityType remote,
  ) async {
    // No-op on web. Firestore is the source of truth.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<void> seedDefaultTypes({required AppUser actor}) async {
    _requireCanManageAbnormalityTypes(actor);
    final createdByUid = actor.uid;
    final createdByName = actor.name;
    final doc = await _types.doc('RA_COIL_COLOUR').get();
    if (doc.exists) return;

    final type = AbnormalityType.seedRaCoilColour(
      createdByUid: createdByUid,
      createdByName: createdByName,
    )..isSynced = true;

    type.firestoreId = 'RA_COIL_COLOUR';
    await saveType(type, actor: actor);
  }

  // ───────────────────────────────────────────────────────────
  // CHARGE ABNORMALITIES
  // ───────────────────────────────────────────────────────────

  @override
  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  ) {
    return _abnormalities
        .where('sourceChargeNo', isEqualTo: sourceChargeNo)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final records = decodeSnapshotDocuments(
            snapshot,
            ChargeAbnormality.fromMap,
            source: 'ChargeAbnormality',
          ).toList();

          records.sort(_sortAbnormalities);
          return records;
        });
  }

  @override
  Stream<List<ChargeAbnormality>> watchAllAbnormalities() {
    return _abnormalities.where('isDeleted', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      final records = decodeSnapshotDocuments(
        snapshot,
        ChargeAbnormality.fromMap,
        source: 'ChargeAbnormality',
      );
      records.sort(_sortAbnormalities);
      return records;
    });
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(
    int sourceChargeNo,
  ) async {
    final snapshot = await _abnormalities
        .where('sourceChargeNo', isEqualTo: sourceChargeNo)
        .where('isDeleted', isEqualTo: false)
        .get();

    final records = snapshot.docs
        .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
        .toList();

    records.sort(_sortAbnormalities);
    return records;
  }

  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async {
    final snapshot = await _abnormalities
        .where('isDeleted', isEqualTo: false)
        .get();

    final records = snapshot.docs
        .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
        .toList();

    records.sort(_sortAbnormalities);
    return records;
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityById(dynamic id) async {
    return getAbnormalityByFirestoreId(id as String);
  }

  @override
  Future<ChargeAbnormality?> getAbnormalityByFirestoreId(
    String firestoreId,
  ) async {
    final doc = await _abnormalities.doc(firestoreId).get();
    if (!doc.exists || doc.data() == null) return null;

    final abnormality = ChargeAbnormality.fromMap(doc.data()!, doc.id);
    if (abnormality.isDeleted) return null;

    return abnormality;
  }

  @override
  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanLogChargeAbnormality(actor);
    _validateAbnormalityForSave(abnormality);

    abnormality.firestoreId ??= _uuid.v4();
    abnormality.normalizeReannealingState();

    final result = await ChargeAbnormalityCommandService().create(
      abnormality: abnormality,
    );
    _copyRemoteChargeAbnormalityIntoLocal(abnormality, result.abnormality);
  }

  @override
  Future<void> updateAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanEditChargeAbnormality(actor);
    _validateAbnormalityForSave(abnormality);

    if (abnormality.firestoreId == null) {
      throw Exception('firestoreId required for abnormality update');
    }

    final beforeDoc = await _abnormalities.doc(abnormality.firestoreId).get();
    final beforeSnapshot = beforeDoc.exists
        ? _sanitizeForAudit(beforeDoc.data())
        : null;

    abnormality.markEdited(
      editedByUid: auditContext?.performedByUid ?? abnormality.updatedByUid,
      editedByName: auditContext?.performedByName ?? abnormality.updatedByName,
    );
    abnormality.isSynced = true;

    await _abnormalities
        .doc(abnormality.firestoreId)
        .set(abnormality.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId!,
        action: AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: abnormality.toAuditMap(),
      );
    }
  }

  @override
  Future<void> softDeleteAbnormality(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanSoftDeleteChargeAbnormality(actor);
    final docId = id as String;

    final beforeDoc = await _abnormalities.doc(docId).get();
    final beforeSnapshot = beforeDoc.exists
        ? _sanitizeForAudit(beforeDoc.data())
        : null;

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
      'updatedByUid': auditContext?.performedByUid,
      'updatedByName': auditContext?.performedByName,
    };

    await _abnormalities.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {...?beforeSnapshot, ...updateData};

      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: docId,
        action: AuditAction.delete,
        context: auditContext,
        before: beforeSnapshot,
        after: afterSnapshot,
      );
    }
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromAbnormalityRemote(
    ChargeAbnormality remote,
  ) async {
    // No-op on web. Firestore is the source of truth.
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  // ───────────────────────────────────────────────────────────
  // SYNC HELPERS
  // ───────────────────────────────────────────────────────────

  @override
  Future<List<AbnormalityType>> getUnsyncedTypes() async => [];

  @override
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities() async => [];

  @override
  Future<void> markTypeSynced(dynamic id, String firestoreId) async {}

  @override
  Future<void> markAbnormalitySynced(dynamic id, String firestoreId) async {}

  @override
  Future<void> markTypesSynced(List<int> ids) async {}

  @override
  Future<void> markTypesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> markAbnormalitiesSynced(List<int> ids) async {}

  @override
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<PaginatedAbnormalityTypesResult> getUpdatedTypes({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The abnormality-type pull has no server upper bound.',
        reasonCode: 'abnormality-type-server-anchor-missing',
      );
    }
    fs.Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _types,
      afterInclusive: since,
      throughInclusive: through,
    );

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get(authoritativeGlobalPullReadOptions);

    if (snapshot.docs.isEmpty) {
      return PaginatedAbnormalityTypesResult(records: [], lastDoc: null);
    }

    return PaginatedAbnormalityTypesResult(
      records: snapshot.docs
          .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
          .toList(),
      lastDoc: snapshot.docs.last,
    );
  }

  @override
  Future<PaginatedChargeAbnormalitiesResult> getUpdatedAbnormalities({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The charge-abnormality pull has no server upper bound.',
        reasonCode: 'charge-abnormality-server-anchor-missing',
      );
    }
    fs.Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _abnormalities,
      afterInclusive: since,
      throughInclusive: through,
    );

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get(authoritativeGlobalPullReadOptions);

    if (snapshot.docs.isEmpty) {
      return PaginatedChargeAbnormalitiesResult(records: [], lastDoc: null);
    }

    return PaginatedChargeAbnormalitiesResult(
      records: snapshot.docs
          .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
          .toList(),
      lastDoc: snapshot.docs.last,
    );
  }

  @override
  Future<List<AbnormalityType>> getTypesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <AbnormalityType>[];

    for (var i = 0; i < firestoreIds.length; i += 30) {
      final end = i + 30 > firestoreIds.length ? firestoreIds.length : i + 30;
      final chunk = firestoreIds.sublist(i, end);

      final snapshot = await _types
          .where(fs.FieldPath.documentId, whereIn: chunk)
          .get();

      results.addAll(
        snapshot.docs.map((doc) => AbnormalityType.fromMap(doc.data(), doc.id)),
      );
    }

    return results;
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];

    final results = <ChargeAbnormality>[];

    for (var i = 0; i < firestoreIds.length; i += 30) {
      final end = i + 30 > firestoreIds.length ? firestoreIds.length : i + 30;
      final chunk = firestoreIds.sublist(i, end);

      final snapshot = await _abnormalities
          .where(fs.FieldPath.documentId, whereIn: chunk)
          .get();

      results.addAll(
        snapshot.docs.map(
          (doc) => ChargeAbnormality.fromMap(doc.data(), doc.id),
        ),
      );
    }

    return results;
  }

  @override
  Future<RemoteRecordApplyResult<AbnormalityType>> applyTypeFromRemote(
    AbnormalityType remote,
  ) {
    throw UnsupportedError(
      'Firestore cannot apply a remote abnormality type to itself.',
    );
  }

  @override
  Future<void> insertTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<void> updateTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<RemoteRecordApplyResult<ChargeAbnormality>> applyAbnormalityFromRemote(
    ChargeAbnormality remote,
  ) {
    throw UnsupportedError(
      'Firestore cannot apply a remote charge abnormality to itself.',
    );
  }

  @override
  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote) async {}

  @override
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote) async {}

  @override
  Future<bool> applyAbnormalityCommandReadback(
    ChargeAbnormality remote,
  ) async => true;

  @override
  Future<bool> applyAbnormalityServerReadbackIfUnchanged(
    ChargeAbnormality remote, {
    required SyncPushSnapshot expectedLocal,
    required bool expectedLocalSynced,
  }) async {
    // Web reads directly from Firestore, so there is no local mirror to race.
    return true;
  }

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    if (records.isEmpty) return;

    final batch = fs.FirebaseFirestore.instance.batch();

    for (final record in records) {
      if (record.firestoreId == null) continue;

      batch.set(
        _types.doc(record.firestoreId),
        record.toMap(),
        fs.SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records) async {
    for (final record in records) {
      final receipt = await ChargeAbnormalityCommandService().create(
        abnormality: record,
      );
      _copyRemoteChargeAbnormalityIntoLocal(record, receipt.abnormality);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
