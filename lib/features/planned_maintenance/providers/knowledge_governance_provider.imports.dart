part of 'knowledge_governance_provider.dart';

Future<void> _knowledgeImportTail = Future.value();

class _KnowledgeImportPaused implements Exception {
  @override
  String toString() =>
      'Sign in with the original import account and current Admin or SI access to continue.';
}

Future<T> _serialKnowledgeImport<T>(Future<T> Function() work) {
  final next = _knowledgeImportTail.then((_) => work());
  _knowledgeImportTail = next.then<void>(
    (_) {},
    onError: (Object _, StackTrace __) {},
  );
  return next;
}

extension _KnowledgeDurableImport on KnowledgeGovernanceController {
  AppUser _requireImportActor(String uid) {
    final current = _currentActor?.call();
    if (current == null ||
        current.uid != uid ||
        !canManageKnowledgeBase(current)) {
      throw _KnowledgeImportPaused();
    }
    return current;
  }

  Future<KnowledgeGovernanceImportApplyResult> _startDurableImport({
    required KnowledgeImportSummary summary,
    required AppUser actor,
  }) {
    _assertCanWrite(actor);
    _requireImportActor(actor.uid);
    // Freeze editor objects before the first asynchronous boundary.
    final entries = [
      for (final entry in summary.accepted)
        (
          code: entry.rowCode,
          draftJson: entry.draft == null
              ? null
              : jsonEncode(entry.draft!.toEntryMap()),
          reason: entry.draft?.changeSummary.trim(),
          version: entry.sourceVersion,
          source: entry.sourceEntryJson,
          beforeJson: entry.sourceCloudJson,
        ),
    ];
    return _serialKnowledgeImport(() async {
      final rows = <KnowledgeImportRowIntent>[];
      for (final entry in entries) {
        final before = entry.beforeJson == null
            ? null
            : BafKnowledgeRow.fromCloudMap(
                jsonDecode(entry.beforeJson!) as Map<String, dynamic>,
                entry.code,
              );
        final reviewedEntry = entry.source == null
            ? null
            : jsonDecode(entry.source!);
        final beforeEntry = before?.toEntryMap();
        if (entry.draftJson == null ||
            entry.reason == null ||
            before?.version != entry.version ||
            (before == null && entry.source != null) ||
            (before != null &&
                (reviewedEntry is! Map<String, dynamic> ||
                    !persistedJsonEquivalent(
                      entry.source!,
                      jsonEncode({
                        for (final key in reviewedEntry.keys)
                          key: beforeEntry![key],
                      }),
                    )))) {
          throw KnowledgeGovernanceException(
            '${entry.code} changed after import review. Nothing was sent; review the import again.',
          );
        }
        rows.add(
          KnowledgeImportRowIntent(
            rowCode: entry.code,
            draftJson: entry.draftJson!,
            reason: entry.reason!,
            beforeJson: entry.beforeJson,
          ),
        );
      }
      _requireImportActor(actor.uid);
      final intent = await _importJournal.retain(
        KnowledgeImportIntent(
          requestId: const Uuid().v4(),
          actorUid: actor.uid,
          actorName: actor.name,
          rows: rows,
        ),
      );
      return _continueImport(KnowledgeImportRecovery(intent, {}));
    });
  }

  Future<KnowledgeGovernanceImportApplyResult> _resumeDurableImport({
    required String importId,
    required AppUser actor,
  }) => _serialKnowledgeImport(() async {
    _assertCanWrite(actor);
    _requireImportActor(actor.uid);
    final saved = (await _importJournal.readAll())
        .where((value) => value.intent.requestId == importId)
        .firstOrNull;
    if (saved == null || saved.intent.actorUid != actor.uid) {
      throw const KnowledgeGovernanceException(
        'The original account must resume its saved import.',
      );
    }
    return _continueImport(saved);
  });

  Future<KnowledgeGovernanceImportApplyResult> _continueImport(
    KnowledgeImportRecovery saved,
  ) async {
    final intent = saved.intent;
    final writes = <KnowledgeGovernanceWriteResult>[];
    final errors = <String>[];
    var rejected = 0;
    var pending = 0;
    for (final row in intent.rows) {
      final prior = saved.outcomes[row.rowCode];
      if (prior?.state == KnowledgeImportOutcomeState.rejected) {
        rejected++;
        errors.add('${row.rowCode}: ${prior!.message}');
        continue;
      }
      KnowledgeGovernanceWriteResult? result;
      KnowledgeImportOutcomeState state;
      String message;
      try {
        _requireImportActor(intent.actorUid);
        result = await _applyRetainedImportRow(intent, row);
        state = KnowledgeImportOutcomeState.accepted;
        message = result.adoption == KnowledgeRevisionAdoption.adopted
            ? 'Accepted revision verified on this device.'
            : 'Accepted revision verified; local adoption still needs review.';
      } on KnowledgeGovernanceException catch (error) {
        // A previously accepted row must never be reclassified as rejected.
        state = prior?.state == KnowledgeImportOutcomeState.accepted
            ? KnowledgeImportOutcomeState.pending
            : KnowledgeImportOutcomeState.rejected;
        message = error.toString();
      } catch (error) {
        state = KnowledgeImportOutcomeState.pending;
        message =
            'Outcome not confirmed. Resume to check the original revision: $error';
      }
      // Persist every observed outcome before attempting the next row. A disk
      // failure stops this run; the immutable intent still permits exact lookup.
      await _importJournal.recordOutcome(
        KnowledgeImportOutcome(
          requestId: const Uuid().v4(),
          importId: intent.requestId,
          rowCode: row.rowCode,
          versionAfter: row.versionAfter,
          state: state,
          adopted: result?.adoption == KnowledgeRevisionAdoption.adopted,
          message: message.length > 2000 ? message.substring(0, 2000) : message,
        ),
      );
      if (result != null) {
        writes.add(result);
      } else {
        errors.add('${row.rowCode}: $message');
        if (state == KnowledgeImportOutcomeState.rejected) {
          rejected++;
        } else {
          pending++;
        }
      }
      // Identity or authority loss pauses the remaining original rows.
      final current = _currentActor?.call();
      if (current?.uid != intent.actorUid || !canManageKnowledgeBase(current)) {
        pending += intent.rows.length - writes.length - rejected - pending;
        break;
      }
    }
    return KnowledgeGovernanceImportApplyResult(
      applied: writes.length,
      rejectedAtSave: rejected,
      pending: pending,
      writes: writes,
      errors: errors,
    );
  }

  Future<KnowledgeGovernanceWriteResult> _applyRetainedImportRow(
    KnowledgeImportIntent intent,
    KnowledgeImportRowIntent row,
  ) async {
    final actor = _requireImportActor(
      intent.actorUid,
    ).copyWith(name: intent.actorName);
    final draft = row.draft;
    final before = row.before;
    final version = row.versionAfter;
    final diff = KnowledgeGovernanceDiff.between(before: before, after: draft);
    if (before != null &&
        (row.reason == before.changeSummary.trim() || diff.isEmpty)) {
      throw const KnowledgeGovernanceException(
        'The reviewed import has no new governed change.',
      );
    }
    final expectedAudit = _revisionAuditMap(
      draft: draft,
      actor: actor,
      version: version,
      before: before,
      action: before == null ? AuditAction.create : AuditAction.update,
      governanceAction: KnowledgeGovernanceAction.importedFromExternal,
    );
    final cloudMap = _draftToCloudMap(
      draft: draft,
      version: version,
      actor: actor,
      isCreate: before == null,
      reason: row.reason,
    );
    final ref = _firestore
        .collection(KnowledgeGovernanceController._collectionPath)
        .doc(row.rowCode);
    final auditRef = _firestore.collection('audit_logs').doc(row.auditId);
    final performedAt = await _firestore.runTransaction<DateTime>((
      transaction,
    ) async {
      _requireImportActor(intent.actorUid);
      final audit = await transaction.get(auditRef);
      if (audit.exists) {
        final accepted = audit.data();
        if (accepted == null || !_matchesImportAudit(accepted, expectedAudit)) {
          throw const KnowledgeGovernanceException(
            'The saved revision identity belongs to different audit evidence. Review this row; it was not retried.',
          );
        }
        return readRequiredPersistedDateTime(
          accepted['timestamp'],
          field: 'timestamp',
          source: row.auditId,
        );
      }
      final current = await transaction.get(ref);
      final data = current.data();
      if ((before == null && current.exists) ||
          (before != null && data == null)) {
        throw const KnowledgeGovernanceException(
          'The row no longer matches the reviewed import baseline.',
        );
      }
      if (before != null) {
        final cloud = BafKnowledgeRow.fromCloudMap(data!, row.rowCode);
        if (!persistedJsonEquivalent(
          row.beforeJson!,
          jsonEncode(
            strictJsonSafeBafKnowledgeMap(
              cloud.toCloudMap(),
              source: 'import transaction pre-image',
            ),
          ),
        )) {
          throw const KnowledgeGovernanceException(
            'The row changed after import review; review the saved proposal again.',
          );
        }
      }
      _requireImportActor(intent.actorUid);
      transaction.set(auditRef, expectedAudit);
      transaction.set(ref, cloudMap, SetOptions(merge: before != null));
      return DateTime.now();
    });
    final adoption = await settleCommittedKnowledgeRevision(
      adoptLocally: () {
        _requireImportActor(intent.actorUid);
        return _adoptAndVerify(
          row.rowCode,
          version,
          _revisionContent(cloudMap),
        );
      },
    );
    return KnowledgeGovernanceWriteResult(
      rowCode: row.rowCode,
      versionAfter: version,
      diff: diff,
      action: KnowledgeGovernanceAction.importedFromExternal,
      performedAt: performedAt,
      adoption: adoption,
    );
  }

  bool _matchesImportAudit(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected,
  ) {
    for (final entry in expected.entries) {
      if (entry.key == 'timestamp') {
        continue;
      }
      if (entry.key == 'beforeJson' || entry.key == 'afterJson') {
        if (entry.value == null
            ? actual[entry.key] != null
            : actual[entry.key] is! String ||
                  !persistedJsonEquivalent(
                    entry.value as String,
                    actual[entry.key] as String,
                  )) {
          return false;
        }
      } else if (actual[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
