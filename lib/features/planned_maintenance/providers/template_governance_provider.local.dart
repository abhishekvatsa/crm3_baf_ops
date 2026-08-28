part of 'template_governance_provider.dart';

class IsarTemplateGovernanceRepository implements TemplateGovernanceRepository {
  IsarTemplateGovernanceRepository({String Function()? auditFirestoreIdFactory})
    : _auditFirestoreIdFactory =
          auditFirestoreIdFactory ?? _newAuditFirestoreId;

  final String Function() _auditFirestoreIdFactory;

  Future<TemplatePublishAudit?> _latestDraftLifecycleAudit(
    String versionFirestoreId,
  ) async {
    final audits =
        await isar.templatePublishAudits
            .filter()
            .versionFirestoreIdEqualTo(versionFirestoreId)
            .findAll();
    audits.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    for (final audit in audits) {
      if (audit.action == TemplatePublishAuditAction.archived ||
          audit.action == TemplatePublishAuditAction.restored) {
        return audit;
      }
    }
    return null;
  }

  Future<void> _requireRestoredDraftAuditSynced(
    TemplateVersion record, {
    required String actionLabel,
  }) async {
    final firestoreId = _cleanOptionalText(record.firestoreId);
    if (firestoreId == null || !record.isDraft) {
      return;
    }

    final latestLifecycleAudit = await _latestDraftLifecycleAudit(firestoreId);
    if (latestLifecycleAudit == null) {
      return;
    }
    if (latestLifecycleAudit.action == TemplatePublishAuditAction.restored &&
        !latestLifecycleAudit.isSynced) {
      throw StateError(
        'Wait for the restored-draft audit to synchronize before this draft can be $actionLabel.',
      );
    }
    if (latestLifecycleAudit.action == TemplatePublishAuditAction.archived) {
      throw StateError(
        'TemplateVersion lifecycle history is inconsistent: an archived draft cannot be $actionLabel as an active draft. Reload governance state.',
      );
    }
  }

  @override
  Future<void> savePackage(
    TemplatePackage record, {
    required AppUser actor,
  }) async {
    _requireTemplateGovernor(actor, 'save template packages');
    _normalizePackageForUserSave(record, actor: actor, markUnsynced: true);
    await isar.writeTxn(() => isar.templatePackages.put(record));
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

    await isar.writeTxn(() async {
      final firestoreId = _cleanOptionalText(record.firestoreId);
      if (firestoreId != null) {
        final current =
            await isar.templateVersions
                .filter()
                .firestoreIdEqualTo(firestoreId)
                .findFirst();
        if (current != null) {
          if (current.version != record.version) {
            throw StateError(
              'TemplateVersion draft changed after it was opened. Reload before saving.',
            );
          }
          if (current.isDeleted || !current.isDraft) {
            throw StateError(
              'Only active draft TemplateVersions can be saved. Reload governance state.',
            );
          }
          await _requireRestoredDraftAuditSynced(current, actionLabel: 'saved');
          record.id = current.id;
        }
      }

      _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);
      await isar.templateVersions.put(record);
    });
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
    await _requireRestoredDraftAuditSynced(record, actionLabel: 'published');

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
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.published,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    );

    await isar.writeTxn(() async {
      await isar.templateVersions.put(record);
      await isar.templatePublishAudits.put(audit);

      final packageId = record.packageFirestoreId;
      if (packageId != null) {
        final package =
            await isar.templatePackages
                .filter()
                .firestoreIdEqualTo(packageId)
                .findFirst();
        if (package != null) {
          package
            ..activeVersionFirestoreId = record.firestoreId
            ..latestVersionNumber =
                record.versionNumber > package.latestVersionNumber
                    ? record.versionNumber
                    : package.latestVersionNumber;
          _normalizePackageForUserSave(
            package,
            actor: actor,
            markUnsynced: true,
          );
          await isar.templatePackages.put(package);
        }
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
    _normalizeVersionForUserSave(record, actor: actor, markUnsynced: true);

    final audit = _newAudit(
      action: TemplatePublishAuditAction.retired,
      actor: actor,
      version: record,
      reason: reason,
      beforeHash: beforeHash,
      afterHash: record.contentHash,
    );

    await isar.writeTxn(() async {
      await isar.templateVersions.put(record);
      await isar.templatePublishAudits.put(audit);

      final packageId = record.packageFirestoreId;
      if (packageId != null) {
        final package =
            await isar.templatePackages
                .filter()
                .firestoreIdEqualTo(packageId)
                .findFirst();
        if (package?.activeVersionFirestoreId == record.firestoreId) {
          package!.activeVersionFirestoreId = null;
          _normalizePackageForUserSave(
            package,
            actor: actor,
            markUnsynced: true,
          );
          await isar.templatePackages.put(package);
        }
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
    await isar.writeTxn(() async {
      final current =
          await isar.templateVersions
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();
      if (current == null) {
        throw StateError('Saved TemplateVersion draft was not found locally.');
      }
      if (current.version != record.version) {
        throw StateError(
          'TemplateVersion draft changed after it was opened. Reload before archiving.',
        );
      }
      if (current.isDeleted || !current.isDraft) {
        throw StateError('Only active draft TemplateVersions can be archived.');
      }
      await _requireRestoredDraftAuditSynced(
        current,
        actionLabel: 'archived again',
      );
      if (!current.isSynced &&
          _cleanOptionalText(current.createdByUid) != actor.uid) {
        throw StateError(
          'An unsynced draft can only be archived by its creator so the remote draft predecessor can be replayed safely.',
        );
      }

      final beforeHash = current.contentHash;
      _applyTemplateVersionDraftLifecycleTransition(
        current,
        status: TemplateVersionStatus.archived,
        actor: actor,
        markUnsynced: true,
      );

      final audit = _newAudit(
        action: TemplatePublishAuditAction.archived,
        actor: actor,
        version: current,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
        firestoreId: _auditFirestoreIdFactory(),
      );

      await isar.templateVersions.put(current);
      await isar.templatePublishAudits.put(audit);
      archived = current;
    });

    _copyTemplateVersionLifecycleState(record, archived, isSynced: false);
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
    await isar.writeTxn(() async {
      final current =
          await isar.templateVersions
              .filter()
              .firestoreIdEqualTo(firestoreId)
              .findFirst();
      if (current == null) {
        throw StateError(
          'Archived TemplateVersion draft was not found locally.',
        );
      }
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
      if (!current.isSynced) {
        throw StateError(
          'Wait for the archived draft to synchronize before restoring it.',
        );
      }
      final latestLifecycleAudit = await _latestDraftLifecycleAudit(
        firestoreId,
      );
      if (latestLifecycleAudit == null ||
          latestLifecycleAudit.action != TemplatePublishAuditAction.archived ||
          !latestLifecycleAudit.isSynced) {
        throw StateError(
          'Wait for the archive audit to synchronize before restoring this draft.',
        );
      }

      final beforeHash = current.contentHash;
      _applyTemplateVersionDraftLifecycleTransition(
        current,
        status: TemplateVersionStatus.draft,
        actor: actor,
        markUnsynced: true,
      );

      final audit = _newAudit(
        action: TemplatePublishAuditAction.restored,
        actor: actor,
        version: current,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
        firestoreId: _auditFirestoreIdFactory(),
      );

      await isar.templateVersions.put(current);
      await isar.templatePublishAudits.put(audit);
      restored = current;
    });

    _copyTemplateVersionLifecycleState(record, restored, isSynced: false);
  }

  @override
  Future<void> saveAudit(TemplatePublishAudit record) async {
    final now = DateTime.now();
    record
      ..firestoreId ??= _newAuditFirestoreId()
      ..performedAt = _readAuditPerformedAtSafely(record) ?? now
      ..updatedAt = now
      ..isSynced = false;
    await isar.writeTxn(() => isar.templatePublishAudits.put(record));
  }

  @override
  Future<List<TemplatePackage>> getAllPackages() async {
    final records =
        await isar.templatePackages.filter().isDeletedEqualTo(false).findAll();
    records.sort((a, b) => a.title.compareTo(b.title));
    return records;
  }

  @override
  Stream<List<TemplatePackage>> watchPackages({int? limit}) {
    if (limit != null) {
      return isar.templatePackages
          .filter()
          .isDeletedEqualTo(false)
          .sortByTitle()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.templatePackages
        .filter()
        .isDeletedEqualTo(false)
        .sortByTitle()
        .watch(fireImmediately: true);
  }

  @override
  Future<TemplatePackage?> getPackageById(dynamic id) async {
    return isar.templatePackages.get(id as int);
  }

  @override
  Future<TemplatePackage?> getPackageByFirestoreId(String firestoreId) async {
    return isar.templatePackages
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  ) async {
    final records =
        await isar.templateVersions
            .filter()
            .packageFirestoreIdEqualTo(packageFirestoreId)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return records;
  }

  @override
  Stream<List<TemplateVersion>> watchVersionsForPackage(
    String packageFirestoreId,
  ) {
    return isar.templateVersions
        .filter()
        .packageFirestoreIdEqualTo(packageFirestoreId)
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((records) {
          records.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
          return records;
        });
  }

  @override
  Future<TemplateVersion?> getVersionById(dynamic id) async {
    return isar.templateVersions.get(id as int);
  }

  @override
  Future<TemplateVersion?> getVersionByFirestoreId(String firestoreId) async {
    return isar.templateVersions
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsForVersion(
    String versionFirestoreId,
  ) async {
    final records =
        await isar.templatePublishAudits
            .filter()
            .versionFirestoreIdEqualTo(versionFirestoreId)
            .and()
            .isDeletedEqualTo(false)
            .findAll();
    records.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return records;
  }

  @override
  Future<TemplatePublishAudit?> getAuditByFirestoreId(
    String firestoreId,
  ) async {
    return isar.templatePublishAudits
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    return isar.templatePackages.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markPackagesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templatePackages.getAll(
            ids,
          )).whereType<TemplatePackage>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templatePackages.putAll(records);
    });
  }

  @override
  Future<void> markPackagesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templatePackages.getAll(
            byId.keys.toList(),
          )).whereType<TemplatePackage>().toList();
      final unchanged = <TemplatePackage>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.templatePackages.putAll(unchanged);
    });
  }

  @override
  Future<void> insertPackageFromRemote(TemplatePackage remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templatePackages.put(remote));
  }

  @override
  Future<void> updatePackageFromRemote(TemplatePackage remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'template package',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local = await getPackageByFirestoreId(remote.firestoreId!);
      if (local == null) return;
      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced template package against remote tombstone in updatePackageFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }
      }
      if (!local.isSynced && remote.updatedAt.isBefore(local.updatedAt)) return;
      remote
        ..id = local.id
        ..isSynced = true;
      await isar.templatePackages.put(remote);
    });
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromPackageRemote(
    TemplatePackage remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'template package',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await getPackageByFirestoreId(remote.firestoreId!);
      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced template package against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remoteDeleteTime
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.templatePackages.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async {
    return isar.templateVersions.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markVersionsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templateVersions.getAll(
            ids,
          )).whereType<TemplateVersion>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templateVersions.putAll(records);
    });
  }

  @override
  Future<void> markVersionsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templateVersions.getAll(
            byId.keys.toList(),
          )).whereType<TemplateVersion>().toList();
      final unchanged = <TemplateVersion>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) await isar.templateVersions.putAll(unchanged);
    });
  }

  @override
  Future<void> insertVersionFromRemote(TemplateVersion remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templateVersions.put(remote));
  }

  @override
  Future<void> updateVersionFromRemote(TemplateVersion remote) async {
    if (remote.firestoreId == null) return;
    final remoteDeleteTime =
        remote.isDeleted
            ? requireRemoteTombstoneDeletedAt(
              remote.deletedAt,
              entityLabel: 'template version',
              firestoreId: remote.firestoreId,
            )
            : null;
    await isar.writeTxn(() async {
      final local = await getVersionByFirestoreId(remote.firestoreId!);
      if (local == null) return;
      if (remote.isDeleted) {
        if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime!)) {
          debugPrint(
            '🛡️ Preserved fresher unsynced template version against remote tombstone in updateVersionFromRemote: '
            'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
            'remoteDeleteTime=$remoteDeleteTime',
          );
          return;
        }
      }
      if (!local.isSynced && remote.updatedAt.isBefore(local.updatedAt)) return;
      remote
        ..id = local.id
        ..isSynced = true;
      await isar.templateVersions.put(remote);
    });
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromVersionRemote(
    TemplateVersion remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'template version',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await getVersionByFirestoreId(remote.firestoreId!);
      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced template version against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remoteDeleteTime=$remoteDeleteTime',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..deletedAt = remoteDeleteTime
        ..deletedByUid = remote.deletedByUid
        ..deletedByName = remote.deletedByName
        ..deleteReason = remote.deleteReason
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..isSynced = true;
      await isar.templateVersions.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async {
    return isar.templatePublishAudits.filter().isSyncedEqualTo(false).findAll();
  }

  @override
  Future<void> markAuditsSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records =
          (await isar.templatePublishAudits.getAll(
            ids,
          )).whereType<TemplatePublishAudit>().toList();
      for (final record in records) {
        record.isSynced = true;
      }
      await isar.templatePublishAudits.putAll(records);
    });
  }

  @override
  Future<void> markAuditsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records =
          (await isar.templatePublishAudits.getAll(
            byId.keys.toList(),
          )).whereType<TemplatePublishAudit>().toList();
      final unchanged = <TemplatePublishAudit>[];
      for (final record in records) {
        final pushed = byId[record.id];
        if (pushed == null) continue;
        if (!pushed.matches(
          currentVersion: record.version,
          currentUpdatedAt: record.updatedAt,
        )) {
          continue;
        }
        record.isSynced = true;
        unchanged.add(record);
      }
      if (unchanged.isNotEmpty) {
        await isar.templatePublishAudits.putAll(unchanged);
      }
    });
  }

  @override
  Future<void> insertAuditFromRemote(TemplatePublishAudit remote) async {
    if (remote.isDeleted) return;
    remote.isSynced = true;
    await isar.writeTxn(() => isar.templatePublishAudits.put(remote));
  }

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromAuditRemote(
    TemplatePublishAudit remote,
  ) async {
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await getAuditByFirestoreId(remote.firestoreId!);
      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }
      if (!local.isSynced && local.updatedAt.isAfter(remote.updatedAt)) {
        debugPrint(
          'Preserved fresher unsynced template publish audit against remote tombstone: '
          'firestoreId=${remote.firestoreId}, local.updatedAt=${local.updatedAt}, '
          'remote.updatedAt=${remote.updatedAt}',
        );
        return RemoteTombstoneApplyResult.localDirtyPreserved(local);
      }

      local
        ..isDeleted = true
        ..updatedAt = remote.updatedAt
        ..version = remote.version
        ..schemaVersion = remote.schemaVersion
        ..isSynced = true;
      await isar.templatePublishAudits.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<PaginatedTemplatePackageResult> getUpdatedPackages({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplatePackageResult(records: const [], lastDoc: null);
  }

  @override
  Future<PaginatedTemplateVersionResult> getUpdatedVersions({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateVersionResult(records: const [], lastDoc: null);
  }

  @override
  Future<PaginatedTemplateAuditResult> getUpdatedAudits({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedTemplateAuditResult(records: const [], lastDoc: null);
  }

  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplatePackage>[];
    for (final id in ids) {
      final record = await getPackageByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertPackages(List<TemplatePackage> records) async {
    await isar.writeTxn(() => isar.templatePackages.putAll(records));
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplateVersion>[];
    for (final id in ids) {
      final record = await getVersionByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertVersions(List<TemplateVersion> records) async {
    await isar.writeTxn(() => isar.templateVersions.putAll(records));
  }

  @override
  Future<void> createRemoteTemplateVersionDraftReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData,
  ) {
    throw UnsupportedError(
      'createRemoteTemplateVersionDraftReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<void> applyRemoteTemplateVersionDraftUpdateReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> draftData, {
    required int expectedDraftVersion,
  }) {
    throw UnsupportedError(
      'applyRemoteTemplateVersionDraftUpdateReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<void> applyRemoteTemplateVersionPublishReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> publishData,
  ) {
    throw UnsupportedError(
      'applyRemoteTemplateVersionPublishReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<void> applyRemoteTemplateVersionArchiveReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> archiveData, {
    required int expectedDraftVersion,
  }) {
    throw UnsupportedError(
      'applyRemoteTemplateVersionArchiveReplayStepForSync is a remote sync primitive and is not '
      'supported by the local Isar template-governance repository.',
    );
  }

  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final records = <TemplatePublishAudit>[];
    for (final id in ids) {
      final record = await getAuditByFirestoreId(id);
      if (record != null) records.add(record);
    }
    return records;
  }

  @override
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records) async {
    await isar.writeTxn(() => isar.templatePublishAudits.putAll(records));
  }
}

Map<String, dynamic> _templateVersionLifecycleTransitionData(
  TemplateVersion record,
) {
  return <String, dynamic>{
    'status': record.status.name,
    'contentHash': record.contentHash,
    'closureReviewConfirmed': record.closureReviewConfirmed,
    'closureCriticalModuleCount': record.closureCriticalModuleCount,
    'closureReviewConfirmedByUid': record.closureReviewConfirmedByUid,
    'closureReviewConfirmedByName': record.closureReviewConfirmedByName,
    'closureReviewConfirmedAt':
        record.closureReviewConfirmedAt?.toIso8601String(),
    'updatedByUid': record.updatedByUid,
    'updatedByName': record.updatedByName,
    'updatedAt': record.updatedAt.toIso8601String(),
    'version': record.version,
  };
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
