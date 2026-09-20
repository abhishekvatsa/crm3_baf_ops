part of 'operational_directive_provider.dart';

class IsarDirectiveRepository implements DirectiveRepository {
  final OrdinaryDirectiveCommands _ordinary;

  IsarDirectiveRepository({
    AuditRepository? auditRepository,
    OrdinaryDirectiveCommands? ordinaryCommands,
  }) : _ordinary = ordinaryCommands ?? OrdinaryDirectiveCommands(web: false);

  @override
  Future<void> saveDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    _requireCanCreateDirective(actor, directive);
    _normalizeDirectiveForLocalWrite(
      directive,
      bumpVersion: false,
      markUnsynced: true,
    );
    if (!isGovernedBurnerRoundDirectiveId(directive.firestoreId)) {
      await _ordinary.save(
        actor: actor,
        action: 'create',
        after: directive,
        reason: 'Issue the reviewed instruction.',
      );
      return;
    }
    await isar.writeTxn(() async {
      await isar.operationalDirectives.put(directive);
    });
  }

  @override
  Future<List<OperationalDirective>> getOpenDirectives() async {
    try {
      return await isar.operationalDirectives
          .filter()
          .group(
            (q) => q
                .statusEqualTo(DirectiveStatus.open)
                .or()
                .statusEqualTo(DirectiveStatus.acknowledged),
          )
          .and()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .findAll();
    } catch (_) {
      final open = await isar.operationalDirectives
          .filter()
          .statusEqualTo(DirectiveStatus.open)
          .and()
          .isDeletedEqualTo(false)
          .findAll();
      final acknowledged = await isar.operationalDirectives
          .filter()
          .statusEqualTo(DirectiveStatus.acknowledged)
          .and()
          .isDeletedEqualTo(false)
          .findAll();
      final all = [...open, ...acknowledged];
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }
  }

  @override
  Stream<List<OperationalDirective>> watchOpenDirectives() {
    return isar.operationalDirectives
        .filter()
        .group(
          (q) => q
              .statusEqualTo(DirectiveStatus.open)
              .or()
              .statusEqualTo(DirectiveStatus.acknowledged),
        )
        .and()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((directives) {
          directives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return directives;
        });
  }

  @override
  Future<List<OperationalDirective>> getAllDirectives() async {
    try {
      return await isar.operationalDirectives
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .findAll();
    } catch (_) {
      final all = await isar.operationalDirectives
          .where()
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }
  }

  @override
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    if (limit != null) {
      return isar.operationalDirectives
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return isar.operationalDirectives
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true)
        .map((directives) {
          directives.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return directives;
        });
  }

  @override
  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    return PaginatedDirectivesResult(records: [], lastDoc: null);
  }

  @override
  Future<void> updateDirective(
    OperationalDirective directive, {
    required AppUser actor,
  }) async {
    final current = await isar.operationalDirectives.get(directive.id);
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
    final current = await isar.operationalDirectives.get(id as int);
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
    if (remote.firestoreId == null) {
      return const RemoteTombstoneApplyResult.localMissing();
    }
    if (!remote.isDeleted) {
      return const RemoteTombstoneApplyResult.notDeletedRemote();
    }
    final remoteDeleteTime = requireRemoteTombstoneDeletedAt(
      remote.deletedAt,
      entityLabel: 'operational directive',
      firestoreId: remote.firestoreId,
    );

    return isar.writeTxn<RemoteTombstoneApplyResult>(() async {
      final local = await isar.operationalDirectives
          .filter()
          .firestoreIdEqualTo(remote.firestoreId!)
          .findFirst();

      if (local == null) return const RemoteTombstoneApplyResult.localMissing();
      if (local.isDeleted) {
        return RemoteTombstoneApplyResult.alreadyDeleted(local);
      }

      if (!local.isSynced && local.updatedAt.isAfter(remoteDeleteTime)) {
        debugPrint(
          '🛡️ Preserved fresher unsynced local directive against remote tombstone: '
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
      await isar.operationalDirectives.put(local);
      return RemoteTombstoneApplyResult.applied(local);
    });
  }

  @override
  Future<void> acknowledgeDirective(
    dynamic id, {
    required AppUser actor,
    required int expectedVersion,
  }) async {
    final current = await isar.operationalDirectives.get(id as int);
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

    final directiveId = id;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null && !d.isDeleted) {
        _requireCanAcknowledgeDirective(actor, d);
        if (d.version != expectedVersion) {
          throw StateError(
            'The directive changed while acknowledgement was being reviewed. Refresh before acknowledging.',
          );
        }
        final now = DateTime.now();
        d.status = DirectiveStatus.acknowledged;
        d.acknowledgedByUid = actor.uid;
        d.acknowledgedByName = actor.name;
        d.acknowledgedAt = now;
        d.updatedAt = now;
        d.version += 1;
        d.isSynced = false;
        await isar.operationalDirectives.put(d);
      }
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
    final current = await isar.operationalDirectives.get(id as int);
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

    final directiveId = id;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null && !d.isDeleted) {
        _requireCanCloseDirective(actor, d);
        if (d.version != expectedVersion) {
          throw StateError(
            'The directive changed while closure was being reviewed. Refresh before closing.',
          );
        }
        final expectedWithoutAcknowledgement =
            d.acknowledgedAt == null && d.acknowledgedByUid == null;
        if (wasUnacknowledged != expectedWithoutAcknowledgement) {
          throw StateError(
            'The directive acknowledgement changed while closure was being reviewed.',
          );
        }
        final now = DateTime.now();
        d.status = DirectiveStatus.closed;
        d.isActive = false;
        d.closedByUid = actor.uid;
        d.closedByName = actor.name;
        d.closedAt = now;
        d.closedWithoutAcknowledgement = wasUnacknowledged;
        if (remarks != null && remarks.isNotEmpty) {
          d.remarks = remarks;
        }
        d.updatedAt = now;
        d.version += 1;
        d.isSynced = false;
        await isar.operationalDirectives.put(d);
      }
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
    await isar.writeTxn(() async {
      final directive = await isar.operationalDirectives
          .filter()
          .firestoreIdEqualTo(firestoreId)
          .findFirst();
      if (directive != null &&
          !directive.isDeleted &&
          directive.isSynced &&
          directive.isClosed &&
          directive.version == committedVersion &&
          directive.closedByUid == actor.uid &&
          directive.closedAt?.toUtc() == closedAt.toUtc() &&
          directive.closedWithoutAcknowledgement == wasUnacknowledged &&
          (remarks == null || directive.remarks == remarks.trim())) {
        return;
      }
      if (directive == null ||
          directive.isDeleted ||
          !directive.isSynced ||
          directive.version != expectedBeforeVersion ||
          committedVersion != expectedBeforeVersion + 1 ||
          directive.isClosed) {
        throw StateError(
          'The local directive changed before the server closure was adopted.',
        );
      }
      directive
        ..status = DirectiveStatus.closed
        ..isActive = false
        ..closedByUid = actor.uid
        ..closedByName = actor.name
        ..closedAt = closedAt
        ..closedWithoutAcknowledgement = wasUnacknowledged
        ..updatedAt = closedAt
        ..version = committedVersion
        ..isSynced = true;
      final cleanedRemarks = remarks?.trim();
      if (cleanedRemarks != null && cleanedRemarks.isNotEmpty) {
        directive.remarks = cleanedRemarks;
      }
      await isar.operationalDirectives.put(directive);
    });
  }

  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async {
    return await isar.operationalDirectives
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> markDirectiveSynced(dynamic id, String firestoreId) async {
    final directiveId = id as int;
    await isar.writeTxn(() async {
      final d = await isar.operationalDirectives.get(directiveId);
      if (d != null) {
        d.firestoreId = firestoreId;
        d.isSynced = true;
        await isar.operationalDirectives.put(d);
      }
    });
  }

  @override
  Future<OperationalDirective?> getByFirestoreId(String firestoreId) async {
    return await isar.operationalDirectives
        .filter()
        .firestoreIdEqualTo(firestoreId)
        .findFirst();
  }

  @override
  Future<RemoteRecordApplyResult<OperationalDirective>>
  applyDirectiveFromRemote(OperationalDirective remote) async {
    final firestoreId = remote.firestoreId?.trim();
    if (firestoreId == null || firestoreId.isEmpty || remote.isDeleted) {
      throw ArgumentError(
        'A non-deleted directive remote with an identity is required.',
      );
    }

    return isar.writeTxn<
      RemoteRecordApplyResult<OperationalDirective>
    >(() async {
      final locals = await isar.operationalDirectives
          .filter()
          .firestoreIdEqualTo(firestoreId)
          .findAll();
      if (locals.length > 1) {
        return RemoteRecordApplyResult<OperationalDirective>(
          RemoteRecordApplyOutcome.duplicateLocalIdentity,
          localRecord: locals.first,
          duplicateCount: locals.length,
        );
      }
      if (locals.isEmpty) {
        remote
          ..id = Isar.autoIncrement
          ..firestoreId = firestoreId
          ..isSynced = true;
        await isar.operationalDirectives.put(remote);
        return RemoteRecordApplyResult<OperationalDirective>(
          RemoteRecordApplyOutcome.inserted,
          localRecord: remote,
        );
      }

      final local = locals.single;
      final remoteIsNewer = _isRemoteNewerByPolicy(local, remote);
      if (!local.isSynced) {
        return RemoteRecordApplyResult<OperationalDirective>(
          RemoteRecordApplyOutcome.localDirtyPreserved,
          localRecord: local,
          remoteIsNewer: remoteIsNewer,
        );
      }
      final sameBoundary =
          local.version == remote.version &&
          local.updatedAt.isAtSameMomentAs(remote.updatedAt) &&
          local.isDeleted == remote.isDeleted;
      if (sameBoundary) {
        final sameContent = sameOrdinaryDirective(local, remote);
        // Repair only the old redundant closed/isActive projection defect.
        // Other same-revision differences remain explicit reconciliation holds.
        final normalized = copyOperationalDirective(local)
          ..isActive = !local.isClosed;
        if (!sameContent &&
            local.isClosed &&
            local.isActive &&
            sameOrdinaryDirective(normalized, remote)) {
          remote
            ..id = local.id
            ..isSynced = true;
          await isar.operationalDirectives.put(remote);
          return RemoteRecordApplyResult<OperationalDirective>(
            RemoteRecordApplyOutcome.updated,
            localRecord: remote,
          );
        }
        return RemoteRecordApplyResult<OperationalDirective>(
          sameContent
              ? RemoteRecordApplyOutcome.unchanged
              : RemoteRecordApplyOutcome.cleanLocalReconciliationRequired,
          localRecord: local,
        );
      }
      if (!SyncRemoteFreshnessPolicy.shouldApplyRemoteToCleanLocal(
        remoteIsNewer: remoteIsNewer,
        localUpdatedAt: local.updatedAt,
        remoteUpdatedAt: remote.updatedAt,
      )) {
        return RemoteRecordApplyResult<OperationalDirective>(
          remoteIsNewer
              ? RemoteRecordApplyOutcome.cleanLocalReconciliationRequired
              : RemoteRecordApplyOutcome.staleRemoteSkipped,
          localRecord: local,
          remoteIsNewer: remoteIsNewer,
        );
      }

      remote
        ..id = local.id
        ..firestoreId = firestoreId
        ..isSynced = true;
      await isar.operationalDirectives.put(remote);
      return RemoteRecordApplyResult<OperationalDirective>(
        RemoteRecordApplyOutcome.updated,
        localRecord: remote,
      );
    });
  }

  @override
  Future<void> insertFromRemote(OperationalDirective remote) async {
    if (remote.isDeleted) return;
    await applyDirectiveFromRemote(remote);
  }

  @override
  Future<void> updateFromRemote(OperationalDirective remote) async {
    if (remote.isDeleted) {
      await applyTombstoneFromDirectiveRemote(remote);
      return;
    }
    await applyDirectiveFromRemote(remote);
  }

  @override
  Future<List<OperationalDirective>> getDirectivesByFirestoreIds(
    List<String> firestoreIds,
  ) async {
    if (firestoreIds.isEmpty) return [];
    final results = <OperationalDirective>[];
    // First try to fetch from Isar (fast path)
    for (final fid in firestoreIds) {
      final local = await isar.operationalDirectives
          .filter()
          .firestoreIdEqualTo(fid)
          .findFirst();
      if (local != null) results.add(local);
    }
    return results;
  }

  @override
  Future<void> batchUpsertDirectives(List<OperationalDirective> records) async {
    await isar.writeTxn(() async {
      for (final r in records) {
        await isar.operationalDirectives.put(r);
      }
    });
  }

  @override
  Future<void> markDirectivesSynced(List<int> ids) async {
    await isar.writeTxn(() async {
      final records = (await isar.operationalDirectives.getAll(
        ids,
      )).whereType<OperationalDirective>().toList();
      for (final r in records) {
        r.isSynced = true;
      }
      await isar.operationalDirectives.putAll(records);
    });
  }

  @override
  Future<void> markDirectivesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final byId = {for (final snapshot in snapshots) snapshot.id: snapshot};

    await isar.writeTxn(() async {
      final records = (await isar.operationalDirectives.getAll(
        byId.keys.toList(),
      )).whereType<OperationalDirective>().toList();
      final unchanged = <OperationalDirective>[];
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
        await isar.operationalDirectives.putAll(unchanged);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────
// FIRESTORE IMPLEMENTATION
// ─────────────────────────────────────────────────────────────
