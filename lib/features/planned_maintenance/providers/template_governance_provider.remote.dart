part of 'template_governance_provider.dart';

class FirestoreTemplateGovernanceRepository
    implements TemplateGovernanceRepository {
  final _packages = FirebaseFirestore.instance.collection('template_packages');
  final _versions = FirebaseFirestore.instance.collection('template_versions');
  final _audits = FirebaseFirestore.instance.collection(
    'template_publish_audits',
  );

  @override
  Future<void> savePackage(
    TemplatePackage record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template packages');
    _normalizePackageForUserSave(record, actor: actor, markUnsynced: false);
    await _packages
        .doc(record.firestoreId)
        .set(record.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveVersion(
    TemplateVersion record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions are editable.');
    }

    final initialFirestoreId = _cleanOptionalText(record.firestoreId);
    if (initialFirestoreId == null) {
      _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);
      await _versions.doc(record.firestoreId).set(record.toMap());
      record.isSynced = true;
      return;
    }

    final expectedVersion = record.version;
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final versionRef = _versions.doc(initialFirestoreId);
      final snapshot = await txn.get(versionRef);
      if (!snapshot.exists) {
        txn.set(versionRef, record.toMap());
        return;
      }

      final current = TemplateVersion.fromMap(snapshot.data()!, snapshot.id);
      if (current.version != expectedVersion) {
        throw StateError(
          'TemplateVersion draft changed after it was opened. Reload before saving.',
        );
      }
      if (current.isDeleted || !current.isDraft) {
        throw StateError(
          'Only active draft TemplateVersions can be saved. Reload governance state.',
        );
      }

      txn.set(versionRef, record.toMap(), SetOptions(merge: true));
    });
    record.isSynced = true;
  }

  @override
  Future<void> publishVersion(
    TemplateVersion record, {
    required AppUser actor,
    String? reason,
  }) async {
    _requireTemplateGovernor(actor, 'publish template versions');
    if (!record.isDraft) {
      throw StateError('Only draft template versions can be published.');
    }
    if (record.firestoreId != null && !record.isSynced) {
      throw StateError(
        'A saved TemplateVersion draft must sync successfully before it can be published.',
      );
    }

    _validateTemplateVersionSnapshotForPublish(record);

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.published
      ..publishedByUid = actor.uid
      ..publishedByName = actor.name
      ..publishedAt = now
      ..updatedAt = now;
    record.refreshContentHash();
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.published,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    )..isSynced = true;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final packageId = record.packageFirestoreId;
      DocumentReference<Map<String, dynamic>>? packageRef;
      DocumentSnapshot<Map<String, dynamic>>? packageSnap;

      if (packageId != null) {
        packageRef = _packages.doc(packageId);
        packageSnap = await txn.get(packageRef);
      }

      txn.set(
        _versions.doc(record.firestoreId),
        record.toMap(),
        SetOptions(merge: true),
      );
      txn.set(
        _audits.doc(audit.firestoreId),
        audit.toMap(),
        SetOptions(merge: true),
      );

      if (packageRef != null) {
        final currentLatest = packageSnap?.data()?['latestVersionNumber'];
        final currentLatestNumber = currentLatest is int ? currentLatest : 0;
        final nextLatestNumber =
            record.versionNumber > currentLatestNumber
                ? record.versionNumber
                : currentLatestNumber;

        txn.set(packageRef, {
          'activeVersionFirestoreId': record.firestoreId,
          'latestVersionNumber': nextLatestNumber,
          'updatedByUid': actor.uid,
          'updatedByName': actor.name,
          'updatedAt': now.toIso8601String(),
          'version': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> retireVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    _requireTemplateGovernor(actor, 'retire template versions');
    if (!record.isPublished) {
      throw StateError('Only published template versions can be retired.');
    }

    final beforeHash = record.contentHash;
    final now = DateTime.now();
    record
      ..status = TemplateVersionStatus.retired
      ..retiredByUid = actor.uid
      ..retiredByName = actor.name
      ..retiredAt = now
      ..retireReason = reason
      ..updatedAt = now;
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: false);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.retired,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    )..isSynced = true;

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final packageId = record.packageFirestoreId;
      DocumentReference<Map<String, dynamic>>? packageRef;
      DocumentSnapshot<Map<String, dynamic>>? packageSnap;

      if (packageId != null) {
        packageRef = _packages.doc(packageId);
        packageSnap = await txn.get(packageRef);
      }

      txn.set(
        _versions.doc(record.firestoreId),
        record.toMap(),
        SetOptions(merge: true),
      );
      txn.set(
        _audits.doc(audit.firestoreId),
        audit.toMap(),
        SetOptions(merge: true),
      );

      final isActiveVersion =
          packageSnap?.data()?['activeVersionFirestoreId'] ==
          record.firestoreId;
      if (packageRef != null && isActiveVersion) {
        txn.set(packageRef, {
          'activeVersionFirestoreId': null,
          'updatedByUid': actor.uid,
          'updatedByName': actor.name,
          'updatedAt': now.toIso8601String(),
          'version': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> archiveDraftVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    _requireTemplateGovernor(actor, 'archive template-version drafts');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('TemplateVersion draft archive reason is required.');
    }

    final firestoreId = _cleanOptionalText(record.firestoreId);
    if (firestoreId == null) {
      throw StateError('Only saved TemplateVersion drafts can be archived.');
    }

    late TemplateVersion archived;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final versionRef = _versions.doc(firestoreId);
      final versionSnap = await txn.get(versionRef);
      if (!versionSnap.exists) {
        throw StateError('Saved TemplateVersion draft was not found remotely.');
      }

      final current = TemplateVersion.fromMap(
        versionSnap.data()!,
        versionSnap.id,
      );
      if (current.version != record.version) {
        throw StateError(
          'TemplateVersion draft changed after it was opened. Reload before archiving.',
        );
      }
      if (current.isDeleted || !current.isDraft) {
        throw StateError('Only active draft TemplateVersions can be archived.');
      }

      final beforeHash = current.contentHash;
      _applyTemplateVersionDraftLifecycleTransition(
        current,
        status: TemplateVersionStatus.archived,
        actor: actor,
        markUnsynced: false,
      );

      final audit = _newAudit(
        action: TemplatePublishAuditAction.archived,
        actor: actor,
        version: current,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
      )..isSynced = true;

      txn.update(versionRef, _templateVersionLifecycleTransitionData(current));
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
      archived = current;
    });

    _copyTemplateVersionLifecycleState(record, archived, isSynced: true);
  }

  @override
  Future<void> restoreArchivedDraftVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    _requireTemplateGovernor(actor, 'restore archived template-version drafts');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('TemplateVersion draft restore reason is required.');
    }

    final firestoreId = _cleanOptionalText(record.firestoreId);
    if (firestoreId == null) {
      throw StateError('Only saved archived drafts can be restored.');
    }

    late TemplateVersion restored;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final versionRef = _versions.doc(firestoreId);
      final versionSnap = await txn.get(versionRef);
      if (!versionSnap.exists) {
        throw StateError(
          'Archived TemplateVersion draft was not found remotely.',
        );
      }

      final current = TemplateVersion.fromMap(
        versionSnap.data()!,
        versionSnap.id,
      );
      if (current.version != record.version) {
        throw StateError(
          'Archived TemplateVersion changed after it was opened. Reload before restoring.',
        );
      }
      if (!current.isArchivedDraft) {
        throw StateError(
          'Only archived draft TemplateVersions can be restored.',
        );
      }

      final beforeHash = current.contentHash;
      _applyTemplateVersionDraftLifecycleTransition(
        current,
        status: TemplateVersionStatus.draft,
        actor: actor,
        markUnsynced: false,
      );

      final audit = _newAudit(
        action: TemplatePublishAuditAction.restored,
        actor: actor,
        version: current,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
      )..isSynced = true;

      txn.update(versionRef, _templateVersionLifecycleTransitionData(current));
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
      restored = current;
    });

    _copyTemplateVersionLifecycleState(record, restored, isSynced: true);
  }

  @override
  Future<void> saveAudit(TemplatePublishAudit record) async {
    record.firestoreId ??= _newAuditFirestoreId();
    record.isSynced = true;
    await _audits
        .doc(record.firestoreId)
        .set(record.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<TemplatePackage>> getAllPackages() async {
    final snap = await _packages.where('isDeleted', isEqualTo: false).get();
    final records =
        snap.docs
            .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
            .toList();
    records.sort((a, b) => a.title.compareTo(b.title));
    return records;
  }

  @override
  Stream<List<TemplatePackage>> watchPackages({int? limit}) {
    Query<Map<String, dynamic>> query = _packages
        .where('isDeleted', isEqualTo: false)
        .orderBy('title');
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<TemplatePackage?> getPackageById(dynamic id) async {
    final doc = await _packages.doc(id as String).get();
    if (!doc.exists) return null;
    return TemplatePackage.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<TemplatePackage?> getPackageByFirestoreId(String firestoreId) async {
    final doc = await _packages.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplatePackage.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  ) async {
    final snap =
        await _versions
            .where('packageFirestoreId', isEqualTo: packageFirestoreId)
            .where('isDeleted', isEqualTo: false)
            .get();
    final records =
        snap.docs
            .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
            .toList();
    records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return records;
  }

  @override
  Stream<List<TemplateVersion>> watchVersionsForPackage(
    String packageFirestoreId,
  ) {
    return _versions
        .where('packageFirestoreId', isEqualTo: packageFirestoreId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final records =
              snap.docs
                  .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
                  .toList();
          records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
          return records;
        });
  }

  @override
  Future<TemplateVersion?> getVersionById(dynamic id) async {
    final doc = await _versions.doc(id as String).get();
    if (!doc.exists) return null;
    return TemplateVersion.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<TemplateVersion?> getVersionByFirestoreId(String firestoreId) async {
    final doc = await _versions.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplateVersion.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsForVersion(
    String versionFirestoreId,
  ) async {
    final snap =
        await _audits
            .where('versionFirestoreId', isEqualTo: versionFirestoreId)
            .get();
    final records =
        snap.docs
            .map((doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id))
            .where((record) => !record.isDeleted)
            .toList();
    records.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return records;
  }

  @override
  Future<TemplatePublishAudit?> getAuditByFirestoreId(
    String firestoreId,
  ) async {
    final doc = await _audits.doc(firestoreId).get();
    if (!doc.exists) return null;
    return TemplatePublishAudit.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async => [];

  @override
  Future<void> markPackagesSynced(List<int> ids) async {}

  @override
  Future<void> markPackagesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertPackageFromRemote(TemplatePackage remote) async {}

  @override
  Future<void> updatePackageFromRemote(TemplatePackage remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromPackageRemote(
    TemplatePackage remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async => [];

  @override
  Future<void> markVersionsSynced(List<int> ids) async {}

  @override
  Future<void> markVersionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertVersionFromRemote(TemplateVersion remote) async {}

  @override
  Future<void> updateVersionFromRemote(TemplateVersion remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromVersionRemote(
    TemplateVersion remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async => [];

  @override
  Future<void> markAuditsSynced(List<int> ids) async {}

  @override
  Future<void> markAuditsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {}

  @override
  Future<void> insertAuditFromRemote(TemplatePublishAudit remote) async {}

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromAuditRemote(
    TemplatePublishAudit remote,
  ) async {
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    return const RemoteTombstoneApplyResult.localMissing();
  }

  @override
  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The template-package pull has no server upper bound.',
        reasonCode: 'template-package-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _packages,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplatePackageResult(
      records:
          snap.docs
              .map((doc) => TemplatePackage.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The template-version pull has no server upper bound.',
        reasonCode: 'template-version-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _versions,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplateVersionResult(
      records:
          snap.docs
              .map((doc) => TemplateVersion.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    if (through == null) {
      throw const GlobalPullProtocolException(
        'The template-audit pull has no server upper bound.',
        reasonCode: 'template-audit-server-anchor-missing',
      );
    }
    Query<Map<String, dynamic>> query = globalPullServerWindowQuery(
      _audits,
      afterInclusive: since,
      throughInclusive: through,
    );
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit).get();
    return PaginatedTemplateAuditResult(
      records:
          snap.docs
              .map((doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id))
              .toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplatePackage>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _packages.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => TemplatePackage.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertPackages(List<TemplatePackage> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        _validatePackageForPersistence(record);
        batch.set(
          _packages.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplateVersion>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _versions.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map((doc) => TemplateVersion.fromMap(doc.data(), doc.id)),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertVersions(List<TemplateVersion> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _versions.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Future<void> createRemoteTemplateVersionDraftReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'createRemoteTemplateVersionDraftReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final ref = _versions.doc(id);
      final snap = await txn.get(ref);
      if (snap.exists) {
        throw StateError(
          'TemplateVersion draft replay refused to overwrite existing remote document: $id',
        );
      }
      txn.set(ref, draftData);
    });
  }

  @override
  Future<void> applyRemoteTemplateVersionDraftUpdateReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData, {
    required int expectedDraftVersion,
  }) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteTemplateVersionDraftUpdateReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final ref = _versions.doc(id);
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw StateError(
          'TemplateVersion draft update replay requires an existing remote draft: $id',
        );
      }
      final remote = TemplateVersion.fromMap(snap.data()!, snap.id);
      if (!remote.isDraft || remote.isDeleted) {
        throw StateError(
          'TemplateVersion draft update replay refused a non-active remote draft: $id',
        );
      }
      if (remote.version != expectedDraftVersion) {
        throw StateError(
          'TemplateVersion draft update replay detected a concurrent remote change. Reload and retry: $id',
        );
      }
      txn.set(ref, draftData, SetOptions(merge: true));
    });
  }

  @override
  Future<void> applyRemoteTemplateVersionPublishReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> publishData,
  ) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteTemplateVersionPublishReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await _versions.doc(id).set(publishData, SetOptions(merge: true));
  }

  @override
  Future<void> applyRemoteTemplateVersionArchiveReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> archiveData, {
    required int expectedDraftVersion,
  }) async {
    final id = _cleanOptionalText(firestoreId);
    if (id == null) {
      throw ArgumentError(
        'applyRemoteTemplateVersionArchiveReplayStepForSync requires a non-empty firestoreId',
      );
    }

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final ref = _versions.doc(id);
      final snapshot = await txn.get(ref);
      if (!snapshot.exists) {
        throw StateError(
          'TemplateVersion archive replay requires an existing remote draft: $id',
        );
      }
      final remote = TemplateVersion.fromMap(snapshot.data()!, snapshot.id);
      if (!remote.isDraft || remote.isDeleted) {
        throw StateError(
          'TemplateVersion archive replay refused a non-active remote draft: $id',
        );
      }
      if (remote.version != expectedDraftVersion) {
        throw StateError(
          'TemplateVersion archive replay detected a concurrent remote change. Reload and retry: $id',
        );
      }
      txn.set(ref, archiveData, SetOptions(merge: true));
    });
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final results = <TemplatePublishAudit>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap =
          await _audits.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(
        snap.docs.map(
          (doc) => TemplatePublishAudit.fromMap(doc.data(), doc.id),
        ),
      );
    }
    return results;
  }

  @override
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final record in records) {
      if (record.firestoreId != null) {
        batch.set(
          _audits.doc(record.firestoreId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────
