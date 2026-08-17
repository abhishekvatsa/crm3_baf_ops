part of 'abnormality_provider.dart';

class FirestoreAbnormalityRepository implements AbnormalityRepository {
  static const _uuid = Uuid();

  final AuditRepository _auditRepo;

  FirestoreAbnormalityRepository({AuditRepository? auditRepository})
    : _auditRepo = auditRepository ?? AuditRepository();

  final fs.CollectionReference<Map<String, dynamic>> _types = fs
      .FirebaseFirestore
      .instance
      .collection('abnormality_types');

  final fs.CollectionReference<Map<String, dynamic>> _abnormalities = fs
      .FirebaseFirestore
      .instance
      .collection('charge_abnormalities');

  final fs.CollectionReference<Map<String, dynamic>> _qualityWarnings = fs
      .FirebaseFirestore
      .instance
      .collection('quality_warnings');

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
          final records =
              snapshot.docs
                  .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
                  .toList();

          records.sort(_sortTypes);
          return records;
        });
  }

  @override
  Stream<List<AbnormalityType>> watchAllTypes() {
    return _types.where('isDeleted', isEqualTo: false).snapshots().map((
      snapshot,
    ) {
      final records =
          snapshot.docs
              .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
              .toList();

      records.sort(_sortTypes);
      return records;
    });
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async {
    final snapshot =
        await _types
            .where('isDeleted', isEqualTo: false)
            .where('isActive', isEqualTo: true)
            .get();

    final records =
        snapshot.docs
            .map((doc) => AbnormalityType.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortTypes);
    return records;
  }

  @override
  Future<List<AbnormalityType>> getAllTypes() async {
    final snapshot = await _types.where('isDeleted', isEqualTo: false).get();

    final records =
        snapshot.docs
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
    _validateTypeForSave(type);

    type.firestoreId ??= _uuid.v4();

    final beforeDoc = await _types.doc(type.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final isCreate = beforeSnapshot == null;

    type
      ..updatedAt = DateTime.now()
      ..version =
          isCreate ? (type.version <= 0 ? 1 : type.version) : type.version + 1
      ..isSynced = true;

    await _types
        .doc(type.firestoreId)
        .set(type.toMap(), fs.SetOptions(merge: true));

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
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    _validateTypeForSave(type);

    if (type.firestoreId == null) {
      throw Exception('firestoreId required for abnormality type update');
    }

    final beforeDoc = await _types.doc(type.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    type.markEdited(
      editedByUid: auditContext?.performedByUid ?? type.lastEditedByUid,
      editedByName: auditContext?.performedByName ?? type.lastEditedByName,
    );
    type.isSynced = true;

    await _types
        .doc(type.firestoreId)
        .set(type.toMap(), fs.SetOptions(merge: true));

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: type.firestoreId!,
        action: AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: type.toAuditMap(),
      );
    }
  }

  @override
  Future<void> softDeleteType(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    _requireCanManageAbnormalityTypes(actor);
    final docId = id as String;

    final beforeDoc = await _types.doc(docId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final now = DateTime.now().toIso8601String();
    final currentVersion = (beforeSnapshot?['version'] as int?) ?? 0;
    final nextVersion = currentVersion + 1;

    final updateData = <String, dynamic>{
      'isDeleted': true,
      'isActive': false,
      'deletedAt': now,
      'deletedByUid': auditContext?.performedByUid,
      'deletedByName': auditContext?.performedByName,
      'deleteReason': auditContext?.reason?.name ?? auditContext?.reasonNotes,
      'updatedAt': now,
      'version': nextVersion,
      'lastEditedByUid': auditContext?.performedByUid,
      'lastEditedByName': auditContext?.performedByName,
    };

    await _types.doc(docId).update(updateData);

    if (auditContext != null) {
      final afterSnapshot = {...?beforeSnapshot, ...updateData};

      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'abnormality_type',
        entityId: docId,
        action: AuditAction.delete,
        context: auditContext,
        before: beforeSnapshot,
        after: afterSnapshot,
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

    await _types.doc('RA_COIL_COLOUR').set(type.toMap());
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
          final records =
              snapshot.docs
                  .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
                  .toList();

          records.sort(_sortAbnormalities);
          return records;
        });
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(
    int sourceChargeNo,
  ) async {
    final snapshot =
        await _abnormalities
            .where('sourceChargeNo', isEqualTo: sourceChargeNo)
            .where('isDeleted', isEqualTo: false)
            .get();

    final records =
        snapshot.docs
            .map((doc) => ChargeAbnormality.fromMap(doc.data(), doc.id))
            .toList();

    records.sort(_sortAbnormalities);
    return records;
  }

  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async {
    final snapshot =
        await _abnormalities.where('isDeleted', isEqualTo: false).get();

    final records =
        snapshot.docs
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

    final beforeDoc = await _abnormalities.doc(abnormality.firestoreId).get();
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

    final isCreate = beforeSnapshot == null;

    abnormality
      ..updatedAt = DateTime.now()
      ..version =
          isCreate
              ? (abnormality.version <= 0 ? 1 : abnormality.version)
              : abnormality.version + 1
      ..isSynced = true;

    if (isCreate) {
      final warning = qualityWarningProjectionForAbnormality(abnormality);
      final warningId = warning['warningId'] as String;
      final warningExists =
          (await _qualityWarnings.doc(warningId).get()).exists;
      final batch = fs.FirebaseFirestore.instance.batch();
      batch.set(
        _abnormalities.doc(abnormality.firestoreId),
        abnormality.toMap(),
        fs.SetOptions(merge: true),
      );
      if (!warningExists) batch.set(_qualityWarnings.doc(warningId), warning);
      await batch.commit();
    } else {
      await _abnormalities
          .doc(abnormality.firestoreId)
          .set(abnormality.toMap(), fs.SetOptions(merge: true));
    }

    if (auditContext != null) {
      _logAudit(
        auditRepository: _auditRepo,
        entityType: 'charge_abnormality',
        entityId: abnormality.firestoreId!,
        action: isCreate ? AuditAction.create : AuditAction.update,
        context: auditContext,
        before: beforeSnapshot,
        after: abnormality.toAuditMap(),
      );
    }
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
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

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
    final beforeSnapshot =
        beforeDoc.exists ? _sanitizeForAudit(beforeDoc.data()) : null;

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

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return PaginatedAbnormalityTypesResult(records: [], lastDoc: null);
    }

    return PaginatedAbnormalityTypesResult(
      records:
          snapshot.docs
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

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return PaginatedChargeAbnormalitiesResult(records: [], lastDoc: null);
    }

    return PaginatedChargeAbnormalitiesResult(
      records:
          snapshot.docs
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

      final snapshot =
          await _types.where(fs.FieldPath.documentId, whereIn: chunk).get();

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

      final snapshot =
          await _abnormalities
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
  Future<void> insertTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<void> updateTypeFromRemote(AbnormalityType remote) async {}

  @override
  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote) async {}

  @override
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote) async {}

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
    if (records.isEmpty) return;

    const maximumPairedRecordsPerBatch = 250;
    for (
      var offset = 0;
      offset < records.length;
      offset += maximumPairedRecordsPerBatch
    ) {
      final chunk = records.sublist(
        offset,
        offset + maximumPairedRecordsPerBatch > records.length
            ? records.length
            : offset + maximumPairedRecordsPerBatch,
      );
      final warnings = <String, Map<String, dynamic>>{};
      for (final record in chunk) {
        if (record.firestoreId == null || record.isDeleted) continue;
        final warning = qualityWarningProjectionForAbnormality(record);
        warnings[warning['warningId'] as String] = warning;
      }
      final existingWarningIds = await _existingQualityWarningIds(
        warnings.keys,
      );
      final batch = fs.FirebaseFirestore.instance.batch();
      for (final record in chunk) {
        if (record.firestoreId == null) continue;
        batch.set(
          _abnormalities.doc(record.firestoreId),
          record.toMap(),
          fs.SetOptions(merge: true),
        );
      }
      for (final entry in warnings.entries) {
        if (!existingWarningIds.contains(entry.key)) {
          batch.set(_qualityWarnings.doc(entry.key), entry.value);
        }
      }

      await batch.commit();
    }
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
              .where(fs.FieldPath.documentId, whereIn: chunk)
              .get();
      existing.addAll(snapshot.docs.map((document) => document.id));
    }
    return existing;
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
