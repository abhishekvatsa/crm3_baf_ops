// FILE: lib/features/planned_maintenance/providers/knowledge_governance_provider.dart
//
// Phase 5E — Knowledge Governance write controller and Riverpod providers.
//
// This file is additive. It does not modify `BafKnowledgeRepository`. It
// composes the existing repository for read/sync and adds governed writes
// for create/update/retire/archive/restore/promote/import.
//
// Every write goes through the same shape:
//   1. Resolve the prior `BafKnowledgeRow` (if any) from the local Isar.
//   2. Compute a `KnowledgeRowDiff` against the proposed `KnowledgeRowDraft`.
//   3. Call `validateForSave(...)` — this mirrors the Firestore rule, so
//      we fail fast in-app rather than burning a Firestore round-trip.
//   4. Write to Firestore (`knowledge_base/{rowCode}`) with monotonic
//      version + change reason + server timestamp. The Firestore rule
//      `validKnowledgeBaseUpdate(...)` is the final authority.
//   5. Commit the structured `audit_logs` event in the same transaction.
//   6. Pull the updated row and verify the exact accepted content was adopted
//      without overwriting retained local work.

import 'dart:async';
import 'dart:convert';
import '../../../core/serialization/persisted_json_equality.dart';
import '../data/remote_baf_knowledge_reader.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../data/baf_knowledge_model.dart';
import '../domain/baf_knowledge_layer.dart';
import '../domain/baf_knowledge_repository.dart';
import '../domain/knowledge_correction_promoter.dart';
import '../domain/knowledge_governance_diff.dart';
import '../domain/knowledge_governance_export.dart';
import '../domain/knowledge_governance_models.dart';
import '../domain/knowledge_revision_settlement.dart';
import '../domain/knowledge_import_journal.dart';
import '../repositories/knowledge_import_journal_repository.dart';

part 'knowledge_governance_provider.imports.dart';

/// Result of a single governed write.
class KnowledgeGovernanceWriteResult {
  final String rowCode;
  final int versionAfter;
  final KnowledgeRowDiff diff;
  final KnowledgeGovernanceAction action;
  final DateTime performedAt;

  /// Whether this device is showing the revision it has just written. The
  /// revision is committed and audited either way; pending means only that
  /// the local copy has not caught up with it.
  final KnowledgeRevisionAdoption adoption;

  const KnowledgeGovernanceWriteResult({
    required this.rowCode,
    required this.versionAfter,
    required this.diff,
    required this.action,
    required this.performedAt,
    this.adoption = KnowledgeRevisionAdoption.adopted,
  });

  KnowledgeGovernanceWriteResult settledAs(
    KnowledgeRevisionAdoption adoption,
  ) => KnowledgeGovernanceWriteResult(
    rowCode: rowCode,
    versionAfter: versionAfter,
    diff: diff,
    action: action,
    performedAt: performedAt,
    adoption: adoption,
  );
}

class KnowledgeGovernanceImportApplyResult {
  final int applied;
  final int rejectedAtSave;
  final List<KnowledgeGovernanceWriteResult> writes;
  final List<String> errors;
  final int pending;

  const KnowledgeGovernanceImportApplyResult({
    required this.applied,
    required this.rejectedAtSave,
    required this.writes,
    required this.errors,
    this.pending = 0,
  });
}

/// Permission gate. Mirrors the Firestore rule (Admin or SI).
bool canManageKnowledgeBase(AppUser? user) {
  if (user == null) return false;
  return user.canManageTemplateGovernance;
}

class KnowledgeGovernanceController {
  KnowledgeGovernanceController({
    FirebaseFirestore? firestore,
    BafKnowledgeRepository? knowledgeRepository,
    AuditRepository? auditRepository,
    KnowledgeImportJournalRepository? importJournal,
    AppUser? Function()? currentActor,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _knowledge = knowledgeRepository ?? BafKnowledgeRepository(),
       _audit = auditRepository ?? AuditRepository(),
       _importJournal = importJournal ?? KnowledgeImportJournalRepository(),
       _currentActor = currentActor;

  final FirebaseFirestore _firestore;
  final BafKnowledgeRepository _knowledge;
  final AuditRepository _audit;
  final KnowledgeImportJournalRepository _importJournal;
  final AppUser? Function()? _currentActor;

  static const String _collectionPath = BafKnowledgeRepository.collectionPath;
  static const int _changeReasonMinLength =
      BafKnowledgeRepository.changeReasonMinLength;

  /// Create a brand-new row. Fails if a row with the same code already
  /// exists in Firestore.
  Future<KnowledgeGovernanceWriteResult> createRow({
    required KnowledgeRowDraft draft,
    required AppUser actor,
    KnowledgeGovernanceAction governanceAction =
        KnowledgeGovernanceAction.created,
  }) async {
    _assertCanWrite(actor);
    final validation = draft.validateForSave(isCreate: true);
    if (!validation.canSave) {
      throw KnowledgeGovernanceException(
        'Validation failed',
        errors: validation.errors,
      );
    }
    final ref = _firestore.collection(_collectionPath).doc(draft.rowCode);
    final diff = KnowledgeGovernanceDiff.between(before: null, after: draft);
    final reason = draft.changeSummary.trim();
    late String acceptedContent;
    final versionAfter = await _firestore.runTransaction<int>((
      transaction,
    ) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        throw KnowledgeGovernanceException(
          'Row ${draft.rowCode} already exists. Use Edit instead.',
        );
      }
      final cloudMap = _draftToCloudMap(
        draft: draft,
        version: 1,
        actor: actor,
        isCreate: true,
        reason: reason,
      );
      acceptedContent = _revisionContent(cloudMap);
      _writeRevisionAudit(
        transaction,
        draft: draft,
        actor: actor,
        version: 1,
        before: null,
        action: AuditAction.create,
        governanceAction: governanceAction,
      );
      transaction.set(ref, cloudMap);
      return 1;
    });
    final result = KnowledgeGovernanceWriteResult(
      rowCode: draft.rowCode,
      versionAfter: versionAfter,
      diff: diff,
      action: governanceAction,
      performedAt: DateTime.now(),
    );
    final adoption = await settleCommittedKnowledgeRevision(
      adoptLocally: () =>
          _adoptAndVerify(draft.rowCode, versionAfter, acceptedContent),
    );
    return result.settledAs(adoption);
  }

  /// Update an existing row. Bumps version by exactly +1 and writes a
  /// structured audit entry containing the diff.
  Future<KnowledgeGovernanceWriteResult> updateRow({
    required BafKnowledgeRow before,
    required KnowledgeRowDraft draft,
    required AppUser actor,
    KnowledgeGovernanceAction? governanceAction,
  }) async {
    _assertCanWrite(actor);
    final validation = draft.validateForSave(isCreate: false);
    if (!validation.canSave) {
      throw KnowledgeGovernanceException(
        'Validation failed',
        errors: validation.errors,
      );
    }
    if (draft.rowCode != before.rowCode) {
      throw const KnowledgeGovernanceException(
        'Row code is immutable. Create a new row to rename.',
      );
    }
    final reason = draft.changeSummary.trim();
    final priorReason = before.changeSummary.trim();
    if (reason == priorReason) {
      throw const KnowledgeGovernanceException(
        'Change reason must differ from the previous version.',
      );
    }
    final diff = KnowledgeGovernanceDiff.between(before: before, after: draft);
    if (diff.isEmpty && draft.lifecycleStatus.name == before.lifecycleStatus) {
      throw const KnowledgeGovernanceException(
        'No fields changed. Use Retire/Archive/Restore for lifecycle moves.',
      );
    }
    final ref = _firestore.collection(_collectionPath).doc(before.rowCode);
    late String acceptedContent;
    final newVersion = await _firestore.runTransaction<int>((
      transaction,
    ) async {
      final current = await transaction.get(ref);
      final data = current.data();
      if (!current.exists || data == null) {
        throw KnowledgeGovernanceException(
          'Row ${before.rowCode} no longer exists in cloud. Refresh before editing.',
        );
      }
      final cloudRow = BafKnowledgeRow.fromCloudMap(data, before.rowCode);
      if (cloudRow.isDeleted) {
        throw KnowledgeGovernanceException(
          'Row ${before.rowCode} was deleted in cloud. Refresh before editing.',
        );
      }
      final cloudVersion = cloudRow.version;
      if (cloudVersion != before.version) {
        throw KnowledgeGovernanceException(
          'Row ${before.rowCode} changed in cloud from v${before.version} to v$cloudVersion. Refresh before editing.',
        );
      }
      if (!persistedJsonEquivalent(
        jsonEncode(before.toEntryMap()),
        jsonEncode(cloudRow.toEntryMap()),
      )) {
        throw const KnowledgeGovernanceException(
          'The reviewed instruction differs from the cloud pre-image. Review the current content before applying this draft.',
        );
      }
      final nextVersion = cloudVersion + 1;
      final cloudMap = _draftToCloudMap(
        draft: draft,
        version: nextVersion,
        actor: actor,
        isCreate: false,
        reason: reason,
      );
      acceptedContent = _revisionContent(cloudMap);
      _writeRevisionAudit(
        transaction,
        draft: draft,
        actor: actor,
        version: nextVersion,
        before: cloudRow,
        action: AuditAction.update,
        governanceAction:
            governanceAction ??
            _resolveLifecycleAction(before: before, after: draft),
      );
      transaction.set(ref, cloudMap, SetOptions(merge: true));
      return nextVersion;
    });
    final action =
        governanceAction ??
        _resolveLifecycleAction(before: before, after: draft);
    final result = KnowledgeGovernanceWriteResult(
      rowCode: before.rowCode,
      versionAfter: newVersion,
      diff: diff,
      action: action,
      performedAt: DateTime.now(),
    );
    // The revision and audit are committed. Readback proves local adoption.
    final adoption = await settleCommittedKnowledgeRevision(
      adoptLocally: () =>
          _adoptAndVerify(before.rowCode, newVersion, acceptedContent),
    );
    return result.settledAs(adoption);
  }

  Future<KnowledgeGovernanceWriteResult> retireRow({
    required BafKnowledgeRow before,
    required AppUser actor,
    required String reason,
  }) => _changeLifecycle(
    before: before,
    actor: actor,
    reason: reason,
    next: KnowledgeLifecycleStatus.retired,
  );

  Future<KnowledgeGovernanceWriteResult> archiveRow({
    required BafKnowledgeRow before,
    required AppUser actor,
    required String reason,
  }) => _changeLifecycle(
    before: before,
    actor: actor,
    reason: reason,
    next: KnowledgeLifecycleStatus.archived,
  );

  Future<KnowledgeGovernanceWriteResult> restoreRow({
    required BafKnowledgeRow before,
    required AppUser actor,
    required String reason,
  }) => _changeLifecycle(
    before: before,
    actor: actor,
    reason: reason,
    next: KnowledgeLifecycleStatus.active,
  );

  /// Promote a tag-resolver correction harvested from a published template
  /// version into a brand-new governed knowledge row. Fails cleanly if the
  /// correction has already been promoted.
  Future<KnowledgeGovernanceWriteResult> promoteCorrection({
    required PromotableTagCorrection correction,
    required AppUser actor,
    required String reason,
    KnowledgeRowDraft? overrideDraft,
  }) async {
    _assertCanWrite(actor);
    if (correction.isAlreadyPromoted) {
      throw KnowledgeGovernanceException(
        'Tag ${correction.normalizedTag} has already been promoted to ${correction.alreadyPromotedTo!.rowCode}.',
      );
    }
    final draft =
        overrideDraft ??
        KnowledgeCorrectionPromoter.buildDraft(
          correction,
          defaultMatrixVersion: BafKnowledgeLayer.matrixVersion,
        );
    final composedReason = reason.trim();
    if (composedReason.length < _changeReasonMinLength) {
      throw const KnowledgeGovernanceException('Promotion reason is required.');
    }
    draft.changeSummary = composedReason;
    return createRow(
      draft: draft,
      actor: actor,
      governanceAction: KnowledgeGovernanceAction.promotedFromTagCorrection,
    );
  }

  /// Apply a parsed `KnowledgeImportSummary`'s accepted drafts as governed
  /// updates. Each draft becomes either a create (if no row exists) or an
  /// update with diff and audit entry. Failures do not roll back prior
  /// successes — by design, the operator gets a per-row outcome.
  Future<KnowledgeGovernanceImportApplyResult> applyImport({
    required KnowledgeImportSummary summary,
    required AppUser actor,
  }) => _startDurableImport(summary: summary, actor: actor);

  Future<KnowledgeGovernanceImportApplyResult> resumeImport({
    required String importId,
    required AppUser actor,
  }) => _resumeDurableImport(importId: importId, actor: actor);

  /// Recent governance audit events, used by the conflict-review tab.
  Future<List<AuditEvent>> recentKnowledgeBaseAudits({int limit = 100}) async {
    final all = await _audit.getAllEventsForEntityType('knowledge_base');
    return all;
  }

  /// Detect potential sync conflicts: local rows with `isSynced == false`
  /// for which Firestore now reports a `version` greater than or equal to
  /// the local one. The operator resolves manually by re-pulling.
  Future<List<KnowledgeSyncConflict>> findSyncConflicts() async {
    if (kIsWeb) return const <KnowledgeSyncConflict>[];
    final unsynced = await _knowledge.getUnsyncedRows();
    if (unsynced.isEmpty) return const <KnowledgeSyncConflict>[];
    final conflicts = <KnowledgeSyncConflict>[];
    for (final local in unsynced) {
      try {
        final cloud = await _firestore
            .collection(_collectionPath)
            .doc(local.rowCode)
            .get();
        final data = cloud.data();
        if (data == null) continue;
        final cloudRow = BafKnowledgeRow.fromCloudMap(data, local.rowCode);
        final cloudVersion = cloudRow.version;
        if (cloudVersion >= local.version) {
          conflicts.add(
            KnowledgeSyncConflict(
              rowCode: local.rowCode,
              localVersion: local.version,
              cloudVersion: cloudVersion,
              cloudUpdatedByName: cloudRow.updatedByName,
              cloudChangeSummary: cloudRow.changeSummary,
              local: local,
            ),
          );
        }
      } on FirebaseException {
        rethrow; // An unavailable comparison is not a verified conflict-free catalogue.
      }
    }
    return conflicts;
  }

  Future<KnowledgeGovernanceWriteResult> _changeLifecycle({
    required BafKnowledgeRow before,
    required AppUser actor,
    required String reason,
    required KnowledgeLifecycleStatus next,
  }) async {
    _assertCanWrite(actor);
    final composedReason = reason.trim();
    if (composedReason.length < _changeReasonMinLength) {
      throw const KnowledgeGovernanceException(
        'Lifecycle change reason is required.',
      );
    }
    final priorStatus = KnowledgeLifecycleStatusX.parse(before.lifecycleStatus);
    if (priorStatus == next) {
      throw KnowledgeGovernanceException(
        'Row ${before.rowCode} is already ${next.name}.',
      );
    }
    final draft = KnowledgeRowDraft.fromRow(before);
    draft.lifecycleStatus = next;
    draft.changeSummary = composedReason;
    return updateRow(before: before, draft: draft, actor: actor);
  }

  Map<String, dynamic> _draftToCloudMap({
    required KnowledgeRowDraft draft,
    required int version,
    required AppUser actor,
    required bool isCreate,
    required String reason,
  }) {
    final entryMap = draft.toEntryMap();
    final now = FieldValue.serverTimestamp();
    return <String, dynamic>{
      ...entryMap,
      'rowCode': draft.rowCode,
      'lifecycleStatus': draft.lifecycleStatus.name,
      'matrixVersion': draft.matrixVersion,
      'schemaVersion': 1,
      'version': version,
      if (isCreate) 'createdByUid': actor.uid,
      if (isCreate) 'createdByName': actor.name,
      if (isCreate) 'createdAt': now,
      'updatedByUid': actor.uid,
      'updatedByName': actor.name,
      'updatedAt': now,
      'changeSummary': reason,
      'isDeleted': false,
    };
  }

  KnowledgeGovernanceAction _resolveLifecycleAction({
    required BafKnowledgeRow before,
    required KnowledgeRowDraft after,
  }) {
    final priorStatus = KnowledgeLifecycleStatusX.parse(before.lifecycleStatus);
    if (priorStatus == after.lifecycleStatus) {
      return KnowledgeGovernanceAction.edited;
    }
    switch (after.lifecycleStatus) {
      case KnowledgeLifecycleStatus.active:
        return KnowledgeGovernanceAction.restored;
      case KnowledgeLifecycleStatus.retired:
        return KnowledgeGovernanceAction.retired;
      case KnowledgeLifecycleStatus.archived:
        return KnowledgeGovernanceAction.archived;
    }
  }

  AuditSeverity _severityFor(
    KnowledgeRowDraft draft, {
    required bool isCreate,
    KnowledgeGovernanceAction? lifecycle,
  }) {
    if (lifecycle == KnowledgeGovernanceAction.archived) {
      return AuditSeverity.high;
    }
    if (lifecycle == KnowledgeGovernanceAction.retired) {
      return AuditSeverity.medium;
    }
    if (draft.requiredForClosure == 'yes' &&
        draft.composerReadiness.name ==
            ComposerReadinessProxy.readyPreset.name) {
      return AuditSeverity.medium;
    }
    return AuditSeverity.low;
  }

  void _writeRevisionAudit(
    Transaction transaction, {
    required KnowledgeRowDraft draft,
    required AppUser actor,
    required int version,
    required BafKnowledgeRow? before,
    required AuditAction action,
    required KnowledgeGovernanceAction governanceAction,
  }) {
    transaction.set(
      _firestore
          .collection('audit_logs')
          .doc('knowledge_revision_${draft.rowCode}_$version'),
      _revisionAuditMap(
        draft: draft,
        actor: actor,
        version: version,
        before: before,
        action: action,
        governanceAction: governanceAction,
      ),
    );
  }

  Map<String, dynamic> _revisionAuditMap({
    required KnowledgeRowDraft draft,
    required AppUser actor,
    required int version,
    required BafKnowledgeRow? before,
    required AuditAction action,
    required KnowledgeGovernanceAction governanceAction,
  }) {
    final beforeJson = before == null
        ? null
        : jsonEncode(
            strictJsonSafeBafKnowledgeMap(
              before.toCloudMap(),
              source: 'knowledge audit before',
            ),
          );
    final afterJson = jsonEncode({
      ...draft.toEntryMap(),
      'version': version,
      'changeSummary': draft.changeSummary.trim(),
      'governanceAction': governanceAction.name,
      'versionAfter': version,
      'diff': KnowledgeGovernanceDiff.between(
        before: before,
        after: draft,
      ).toMap(),
    });
    // Match audit admission before committing either side of the transaction.
    if ((beforeJson?.length ?? 0) > 20000 ||
        afterJson.length > 20000 ||
        draft.changeSummary.trim().length > 2000) {
      throw const KnowledgeGovernanceException(
        'This revision exceeds the retained audit size. Split the reviewed change before saving.',
      );
    }
    return {
      'entityType': 'knowledge_base',
      'entityId': draft.rowCode,
      'action': action.name,
      'performedByUid': actor.uid,
      'performedByName': actor.name,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': AuditReason.manualOverride.name,
      'reasonNotes': draft.changeSummary.trim(),
      'summary':
          '${governanceAction.displayLabel} ${draft.rowCode} (v$version)',
      'severity': _severityFor(
        draft,
        isCreate: before == null,
        lifecycle: governanceAction,
      ).name,
      'beforeJson': beforeJson,
      'afterJson': afterJson,
    };
  }

  // Timestamps are server-generated. Retain every other accepted field before
  // readback, independently of later editor-draft mutation.
  String _revisionContent(Map<String, dynamic> cloudMap) => jsonEncode({
    for (final entry in cloudMap.entries)
      if (entry.value is! FieldValue) entry.key: entry.value,
  });

  Future<KnowledgeRevisionAdoption> _adoptAndVerify(
    String rowCode,
    int version,
    String acceptedContent,
  ) async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .doc(rowCode)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Accepted knowledge revision is unavailable.');
    }
    final cloud = BafKnowledgeRow.fromCloudMap(data, rowCode);
    if (cloud.version != version) {
      throw StateError(
        'The catalogue has advanced beyond the accepted revision.',
      );
    }
    final expected = jsonDecode(acceptedContent) as Map<String, dynamic>;
    final cloudMap = cloud.toCloudMap();
    if (!persistedJsonEquivalent(
      acceptedContent,
      jsonEncode({for (final key in expected.keys) key: cloudMap[key]}),
    )) {
      throw StateError('Readback differs from the accepted knowledge content.');
    }
    if (kIsWeb) {
      return KnowledgeRevisionAdoption.adopted;
    }
    await _knowledge.pullCloudToLocal();
    final local = (await _knowledge.getAllLocalRows(
      includeDeleted: true,
    )).where((row) => row.rowCode == rowCode).firstOrNull;
    if (local == null ||
        !local.isSynced ||
        !persistedJsonEquivalent(
          jsonEncode(
            strictJsonSafeBafKnowledgeMap(
              local.toCloudMap(),
              source: 'local knowledge',
            ),
          ),
          jsonEncode(
            strictJsonSafeBafKnowledgeMap(
              cloud.toCloudMap(),
              source: 'cloud knowledge',
            ),
          ),
        )) {
      throw StateError(
        'Accepted knowledge is not yet adopted; retained local work needs review.',
      );
    }
    return KnowledgeRevisionAdoption.adopted;
  }

  void _assertCanWrite(AppUser actor) {
    if (!canManageKnowledgeBase(actor)) {
      throw const KnowledgeGovernanceException(
        'Only Admin or SI may manage the BAF Knowledge Base.',
      );
    }
  }
}

class KnowledgeGovernanceException implements Exception {
  final String message;
  final List<String>? errors;

  const KnowledgeGovernanceException(this.message, {this.errors});

  @override
  String toString() {
    if (errors == null || errors!.isEmpty) return message;
    return '$message: ${errors!.join('; ')}';
  }
}

class KnowledgeSyncConflict {
  final String rowCode;
  final int localVersion;
  final int cloudVersion;
  final String cloudUpdatedByName;
  final String cloudChangeSummary;
  final BafKnowledgeRow local;

  const KnowledgeSyncConflict({
    required this.rowCode,
    required this.localVersion,
    required this.cloudVersion,
    required this.cloudUpdatedByName,
    required this.cloudChangeSummary,
    required this.local,
  });
}

/// Tiny shim so we don't have to import module_composer_models from the
/// audit-severity helper above. (The string is the only thing we need.)
class ComposerReadinessProxy {
  static const ComposerReadinessProxy readyPreset = ComposerReadinessProxy._(
    'readyPreset',
  );
  final String name;
  const ComposerReadinessProxy._(this.name);
}

// ─────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────────────────

final knowledgeGovernanceControllerProvider =
    Provider<KnowledgeGovernanceController>((ref) {
      return KnowledgeGovernanceController(
        knowledgeRepository: ref.watch(bafKnowledgeRepositoryProvider),
        auditRepository: ref.read(auditRepositoryProvider),
        importJournal: ref.watch(knowledgeImportJournalRepositoryProvider),
        currentActor: () => ref.read(currentAppUserProvider).valueOrNull,
      );
    });

class KnowledgeRowsView {
  final List<BafKnowledgeRow> rows;
  final BafKnowledgeMatrixMeta meta;

  const KnowledgeRowsView({required this.rows, required this.meta});
}

/// Stream of *all* rows (active + retired + archived) plus matrix meta.
/// This is intentionally backed by the repository's Isar-first watcher on
/// mobile, not by a Firestore polling loop. Cloud pulls update Isar; Isar then
/// pushes the update into this StreamProvider just like the rest of the app's
/// offline-first screens.
final knowledgeRowsViewProvider = StreamProvider<KnowledgeRowsView>((ref) {
  final repository = ref.watch(bafKnowledgeRepositoryProvider);
  final controller = StreamController<KnowledgeRowsView>();

  List<BafKnowledgeRow>? latestRows;
  BafKnowledgeMatrixMeta? latestMeta;

  void emitIfReady() {
    final rows = latestRows;
    final meta = latestMeta;
    if (rows == null || meta == null || controller.isClosed) return;
    controller.add(KnowledgeRowsView(rows: rows, meta: meta));
  }

  final rowsSub = repository.watchAllKnowledgeRows().listen(
    (rows) {
      latestRows = rows;
      emitIfReady();
    },
    onError: (Object error, StackTrace stackTrace) {
      latestRows = null;
      if (!controller.isClosed) controller.addError(error, stackTrace);
    },
  );
  final metaSub = repository.watchMatrixMeta().listen(
    (meta) {
      latestMeta = meta;
      emitIfReady();
    },
    onError: (Object error, StackTrace stackTrace) {
      latestMeta = null;
      if (!controller.isClosed) controller.addError(error, stackTrace);
    },
  );

  ref.onDispose(() async {
    await rowsSub.cancel();
    await metaSub.cancel();
    await controller.close();
  });

  return controller.stream;
});

/// Synthesised export bundle of the currently visible rows.
final knowledgeExportBundleProvider =
    Provider.family<KnowledgeBundleExport, KnowledgeBundleFormat>((
      ref,
      format,
    ) {
      final view = ref.watch(knowledgeRowsViewProvider).requireValue;
      final rows = view.rows;
      return KnowledgeGovernanceExport.export(
        rows,
        format: format,
        matrixVersion: view.meta.matrixVersion,
      );
    });

/// Recent governance audit log entries (knowledge_base only).
final knowledgeGovernanceAuditFeedProvider =
    FutureProvider.autoDispose<List<AuditEvent>>((ref) async {
      return ref
          .watch(knowledgeGovernanceControllerProvider)
          .recentKnowledgeBaseAudits();
    });

/// Currently outstanding sync conflicts on knowledge rows.
final knowledgeGovernanceSyncConflictsProvider =
    FutureProvider.autoDispose<List<KnowledgeSyncConflict>>((ref) async {
      return ref
          .watch(knowledgeGovernanceControllerProvider)
          .findSyncConflicts();
    });

/// Filter state for the Knowledge Governance screen. UI-owned, so the
/// screen can update it freely without rebuilding the Firestore query.
final knowledgeGovernanceFilterProvider =
    StateProvider<KnowledgeGovernanceFilter>((ref) {
      return KnowledgeGovernanceFilter.allActive();
    });
