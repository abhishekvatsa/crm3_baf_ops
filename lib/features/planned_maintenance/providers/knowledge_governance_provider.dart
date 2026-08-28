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
//   5. On success, write a structured audit event into `audit_logs`.
//   6. Pull the updated row back into the local Isar via the existing
//      `BafKnowledgeRepository.pullCloudToLocal(...)`.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/data/user_model.dart';
import '../data/baf_knowledge_model.dart';
import '../domain/baf_knowledge_layer.dart';
import '../domain/baf_knowledge_repository.dart';
import '../domain/knowledge_correction_promoter.dart';
import '../domain/knowledge_governance_diff.dart';
import '../domain/knowledge_governance_export.dart';
import '../domain/knowledge_governance_models.dart';

/// Result of a single governed write.
class KnowledgeGovernanceWriteResult {
  final String rowCode;
  final int versionAfter;
  final KnowledgeRowDiff diff;
  final KnowledgeGovernanceAction action;
  final DateTime performedAt;

  const KnowledgeGovernanceWriteResult({
    required this.rowCode,
    required this.versionAfter,
    required this.diff,
    required this.action,
    required this.performedAt,
  });
}

class KnowledgeGovernanceImportApplyResult {
  final int applied;
  final int rejectedAtSave;
  final List<KnowledgeGovernanceWriteResult> writes;
  final List<String> errors;

  const KnowledgeGovernanceImportApplyResult({
    required this.applied,
    required this.rejectedAtSave,
    required this.writes,
    required this.errors,
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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _knowledge = knowledgeRepository ?? BafKnowledgeRepository(),
       _audit = auditRepository ?? AuditRepository();

  final FirebaseFirestore _firestore;
  final BafKnowledgeRepository _knowledge;
  final AuditRepository _audit;

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
    final versionAfter = await _firestore.runTransaction<int>((
      transaction,
    ) async {
      final existing = await transaction.get(ref);
      final data = existing.data();
      if (existing.exists && data?['isDeleted'] != true) {
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
      transaction.set(ref, cloudMap);
      return 1;
    });
    await _knowledge.pullCloudToLocal();
    final result = KnowledgeGovernanceWriteResult(
      rowCode: draft.rowCode,
      versionAfter: versionAfter,
      diff: diff,
      action: governanceAction,
      performedAt: DateTime.now(),
    );
    await _logAudit(
      action: AuditAction.create,
      result: result,
      actor: actor,
      reason: reason,
      severity: _severityFor(draft, isCreate: true),
    );
    return result;
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
      final nextVersion = cloudVersion + 1;
      final cloudMap = _draftToCloudMap(
        draft: draft,
        version: nextVersion,
        actor: actor,
        isCreate: false,
        reason: reason,
      );
      transaction.set(ref, cloudMap, SetOptions(merge: true));
      return nextVersion;
    });
    await _knowledge.pullCloudToLocal();

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
    await _logAudit(
      action:
          action == KnowledgeGovernanceAction.retired ||
                  action == KnowledgeGovernanceAction.archived
              ? AuditAction.delete
              : AuditAction.update,
      result: result,
      actor: actor,
      reason: reason,
      severity: _severityFor(draft, isCreate: false, lifecycle: action),
    );
    return result;
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
  }) async {
    _assertCanWrite(actor);
    final writes = <KnowledgeGovernanceWriteResult>[];
    final errors = <String>[];
    var rejected = 0;
    final byCode = await _localRowsByCode();
    for (final entry in summary.accepted) {
      final draft = entry.draft;
      if (draft == null) {
        rejected++;
        errors.add('${entry.rowCode}: empty draft');
        continue;
      }
      try {
        final existing = byCode[draft.rowCode];
        final result =
            existing == null
                ? await createRow(
                  draft: draft,
                  actor: actor,
                  governanceAction:
                      KnowledgeGovernanceAction.importedFromExternal,
                )
                : await updateRow(
                  before: existing,
                  draft: draft,
                  actor: actor,
                  governanceAction:
                      KnowledgeGovernanceAction.importedFromExternal,
                );
        writes.add(result);
      } catch (e) {
        rejected++;
        errors.add('${draft.rowCode}: $e');
      }
    }
    return KnowledgeGovernanceImportApplyResult(
      applied: writes.length,
      rejectedAtSave: rejected,
      writes: writes,
      errors: errors,
    );
  }

  /// Recent governance audit events, used by the conflict-review tab.
  Future<List<AuditEvent>> recentKnowledgeBaseAudits({int limit = 100}) async {
    final all = await _audit.getRecentLocalEvents(limit: limit * 3);
    return all
        .where((event) => event.entityType == 'knowledge_base')
        .take(limit)
        .toList();
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
        final cloud =
            await _firestore
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
        // Network/permission errors are not conflicts.
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

  Future<void> _logAudit({
    required AuditAction action,
    required KnowledgeGovernanceWriteResult result,
    required AppUser actor,
    required String reason,
    required AuditSeverity severity,
  }) async {
    final event = AuditEvent(
      entityType: 'knowledge_base',
      entityId: result.rowCode,
      action: action,
      performedByUid: actor.uid,
      performedByName: actor.name,
      reason: AuditReason.manualOverride,
      reasonNotes: reason,
      summary:
          '${result.action.displayLabel} ${result.rowCode} (v${result.versionAfter})',
      severity: severity,
      after: <String, dynamic>{
        'governanceAction': result.action.name,
        'versionAfter': result.versionAfter,
        'diff': result.diff.toMap(),
      },
    );
    try {
      await _audit.log(event);
    } catch (_) {
      // Audit failures must not block the governance write itself; the
      // local Isar cache will retry on next sync.
    }
  }

  void _assertCanWrite(AppUser actor) {
    if (!canManageKnowledgeBase(actor)) {
      throw const KnowledgeGovernanceException(
        'Only Admin or SI may manage the BAF Knowledge Base.',
      );
    }
  }

  Future<Map<String, BafKnowledgeRow>> _localRowsByCode() async {
    final rows = await _knowledge.getAllLocalRows();
    return <String, BafKnowledgeRow>{for (final row in rows) row.rowCode: row};
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

  final rowsSub = repository.watchAllKnowledgeRows().listen((rows) {
    latestRows = rows;
    emitIfReady();
  }, onError: controller.addError);
  final metaSub = repository.watchMatrixMeta().listen((meta) {
    latestMeta = meta;
    emitIfReady();
  }, onError: controller.addError);

  ref.onDispose(() async {
    await rowsSub.cancel();
    await metaSub.cancel();
    await controller.close();
  });

  return controller.stream;
});

/// Synthesised export bundle of the currently visible rows.
final knowledgeExportBundleProvider = Provider.family<
  KnowledgeBundleExport,
  KnowledgeBundleFormat
>((ref, format) {
  final view = ref.watch(knowledgeRowsViewProvider).valueOrNull;
  final rows = view?.rows ?? const <BafKnowledgeRow>[];
  return KnowledgeGovernanceExport.export(
    rows,
    format: format,
    matrixVersion: view?.meta.matrixVersion ?? BafKnowledgeLayer.matrixVersion,
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
