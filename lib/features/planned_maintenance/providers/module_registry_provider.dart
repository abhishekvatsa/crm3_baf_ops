import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../data/module_registry_model.dart';
import '../domain/module_composer_models.dart';

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

void _requireRegistryGovernor(AppUser actor, String actionLabel) {
  if (!actor.canManageTemplateGovernance) {
    throw StateError('Not authorized to $actionLabel.');
  }
}

String _newAuditFirestoreId() =>
    FirebaseFirestore.instance.collection('module_registry_audits').doc().id;

class ModuleRegistryRepository {
  final FirebaseFirestore _firestore;

  ModuleRegistryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _families =>
      _firestore.collection('module_registry');

  CollectionReference<Map<String, dynamic>> get _audits =>
      _firestore.collection('module_registry_audits');

  CollectionReference<Map<String, dynamic>> _revisions(
    String registryModuleId,
  ) => _families.doc(registryModuleId).collection('revisions');

  Future<ModuleRegistryRevision> createDraftFromModule({
    required ComposerModuleDraft module,
    required AppUser actor,
    required String sourceType,
    Map<String, dynamic> lineage = const <String, dynamic>{},
    String? reason,
  }) async {
    _requireRegistryGovernor(actor, 'create module registry drafts');
    final registryModuleId = moduleRegistryIdForModule(module);
    final familyRef = _families.doc(registryModuleId);
    final revisionRef = _revisions(registryModuleId).doc();
    final now = DateTime.now();

    final lineagePayload = <String, dynamic>{
      'sourceType': sourceType,
      ...lineage,
      'createdFromWorkshop': true,
    };

    final draft = ModuleRegistryRevision.draftFromModule(
      registryModuleId: registryModuleId,
      revisionId: revisionRef.id,
      module: module,
      actor: actor,
      lineage: lineagePayload,
      now: now,
    );

    final audit = _audit(
      registryModuleId: registryModuleId,
      revisionId: draft.revisionId,
      revisionNumber: draft.revisionNumber,
      action: ModuleRegistryAuditAction.draftCreated,
      actor: actor,
      reason: reason,
      afterHash: draft.contentHash,
      lineage: lineagePayload,
      now: now,
    );

    await _firestore.runTransaction((txn) async {
      final familySnap = await txn.get(familyRef);
      if (familySnap.exists) {
        final family = ModuleRegistryFamily.fromMap(
          familySnap.data()!,
          familySnap.id,
        );
        if (!family.isActive) {
          throw StateError('Only active registry families can receive drafts.');
        }
      } else {
        final family = ModuleRegistryFamily.fromModule(
          module: module,
          actor: actor,
          now: now,
        );
        txn.set(familyRef, family.toMap());
      }
      txn.set(revisionRef, draft.toMap());
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
    });

    return draft;
  }

  Future<void> updateDraftRevision({
    required ModuleRegistryRevision revision,
    required ComposerModuleDraft module,
    required AppUser actor,
    required String sourceType,
    Map<String, dynamic> lineage = const <String, dynamic>{},
    String? reason,
  }) async {
    _requireRegistryGovernor(actor, 'edit module registry drafts');

    final lineagePayload = <String, dynamic>{
      'sourceType': sourceType,
      ...lineage,
      'createdFromWorkshop': true,
    };

    await _firestore.runTransaction((txn) async {
      final familyRef = _families.doc(revision.registryModuleId);
      final revisionRef = _revisions(
        revision.registryModuleId,
      ).doc(revision.revisionId);
      final familySnap = await txn.get(familyRef);
      final revisionSnap = await txn.get(revisionRef);
      if (!revisionSnap.exists) {
        throw StateError('Registry draft not found.');
      }

      final current = ModuleRegistryRevision.fromMap(
        revisionSnap.data()!,
        revisionSnap.id,
      );
      if (!current.isDraft) {
        throw StateError('Only draft registry revisions are editable.');
      }
      final beforeHash = current.contentHash;
      current.refreshDraftFromModule(
        module: module,
        actor: actor,
        lineage: lineagePayload,
      );

      if (!familySnap.exists) {
        throw StateError('Registry family not found.');
      }
      final family = ModuleRegistryFamily.fromMap(
        familySnap.data()!,
        familySnap.id,
      );
      if (!family.isActive) {
        throw StateError('Only active registry families can edit drafts.');
      }

      final audit = _audit(
        registryModuleId: current.registryModuleId,
        revisionId: current.revisionId,
        revisionNumber: current.revisionNumber,
        action: ModuleRegistryAuditAction.draftUpdated,
        actor: actor,
        reason: reason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
        lineage: lineagePayload,
      );

      txn.update(revisionRef, current.toMap());
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
    });
  }

  Future<ModuleRegistryRevision?> _loadLegacyLatestPublishedRevision(
    String registryModuleId,
  ) async {
    final snapshot = await _revisions(registryModuleId).get();
    ModuleRegistryRevision? latest;
    for (final document in snapshot.docs) {
      final revision = ModuleRegistryRevision.fromMap(
        document.data(),
        document.id,
      );
      if (revision.revisionNumber <= 0 ||
          (!revision.isPublished && !revision.isRetired)) {
        continue;
      }
      if (latest == null || revision.revisionNumber > latest.revisionNumber) {
        latest = revision;
        continue;
      }
      if (revision.revisionNumber == latest.revisionNumber &&
          revision.revisionId != latest.revisionId) {
        throw StateError(
          'Registry publication history is ambiguous: multiple revisions claim latest published number '
          '${revision.revisionNumber}. Repair governance history before publishing.',
        );
      }
    }
    return latest;
  }

  Future<void> _ensureLatestPublishedPointers({
    required String registryModuleId,
    required AppUser actor,
  }) async {
    final familyRef = _families.doc(registryModuleId);
    final preflightFamilySnap = await familyRef.get();
    if (!preflightFamilySnap.exists) {
      return;
    }

    final preflightFamily = ModuleRegistryFamily.fromMap(
      preflightFamilySnap.data()!,
      preflightFamilySnap.id,
    );
    if (preflightFamily.latestPublishedRevisionNumber <= 0) {
      return;
    }

    final existingRevisionId =
        preflightFamily.latestPublishedRevisionId?.trim();
    final existingHash = preflightFamily.latestPublishedContentHash?.trim();
    if (existingRevisionId != null &&
        existingRevisionId.isNotEmpty &&
        existingHash != null &&
        existingHash.isNotEmpty) {
      return;
    }

    ModuleRegistryRevision? candidate;
    if (existingRevisionId != null && existingRevisionId.isNotEmpty) {
      final candidateSnap =
          await _revisions(registryModuleId).doc(existingRevisionId).get();
      if (candidateSnap.exists) {
        candidate = ModuleRegistryRevision.fromMap(
          candidateSnap.data()!,
          candidateSnap.id,
        );
      }
    } else {
      candidate = await _loadLegacyLatestPublishedRevision(registryModuleId);
    }

    if (candidate == null ||
        candidate.revisionNumber !=
            preflightFamily.latestPublishedRevisionNumber ||
        (!candidate.isPublished && !candidate.isRetired)) {
      throw StateError(
        'Registry latest-published pointers are missing and the historical revision cannot be resolved safely.',
      );
    }
    if (existingHash != null &&
        existingHash.isNotEmpty &&
        existingHash != candidate.contentHash) {
      throw StateError(
        'Registry latest-published hash metadata conflicts with historical revision content.',
      );
    }

    await _firestore.runTransaction((txn) async {
      final familySnap = await txn.get(familyRef);
      if (!familySnap.exists) {
        throw StateError('Registry family not found.');
      }
      final currentFamily = ModuleRegistryFamily.fromMap(
        familySnap.data()!,
        familySnap.id,
      );
      final currentRevisionId = currentFamily.latestPublishedRevisionId?.trim();
      final currentHash = currentFamily.latestPublishedContentHash?.trim();
      if (currentRevisionId != null &&
          currentRevisionId.isNotEmpty &&
          currentHash != null &&
          currentHash.isNotEmpty) {
        return;
      }
      if (!currentFamily.isActive ||
          currentFamily.latestPublishedRevisionNumber !=
              preflightFamily.latestPublishedRevisionNumber) {
        throw StateError(
          'Registry publication history changed while latest-published pointers were being repaired. Reload and retry.',
        );
      }
      if (currentRevisionId != null &&
          currentRevisionId.isNotEmpty &&
          currentRevisionId != candidate!.revisionId) {
        throw StateError(
          'Registry latest-published revision pointer changed unexpectedly.',
        );
      }
      if (currentHash != null &&
          currentHash.isNotEmpty &&
          currentHash != candidate!.contentHash) {
        throw StateError(
          'Registry latest-published hash pointer changed unexpectedly.',
        );
      }

      final revisionRef = _revisions(
        registryModuleId,
      ).doc(candidate!.revisionId);
      final revisionSnap = await txn.get(revisionRef);
      if (!revisionSnap.exists) {
        throw StateError(
          'Registry latest published revision disappeared during pointer repair.',
        );
      }
      final currentRevision = ModuleRegistryRevision.fromMap(
        revisionSnap.data()!,
        revisionSnap.id,
      );
      if (currentRevision.revisionNumber !=
              currentFamily.latestPublishedRevisionNumber ||
          (!currentRevision.isPublished && !currentRevision.isRetired) ||
          currentRevision.contentHash != candidate.contentHash) {
        throw StateError(
          'Registry historical revision changed during pointer repair. Reload and retry.',
        );
      }

      final now = DateTime.now();
      txn.update(familyRef, <String, dynamic>{
        'latestPublishedRevisionId': currentRevision.revisionId,
        'latestPublishedContentHash': currentRevision.contentHash,
        'updatedByUid': actor.uid,
        'updatedByName': actor.name,
        'updatedAt': now.toIso8601String(),
        'version': currentFamily.version + 1,
      });
    });
  }

  Future<ModuleRegistryRevision> publishDraftRevision({
    required String registryModuleId,
    required String revisionId,
    required AppUser actor,
    required String reason,
  }) async {
    _requireRegistryGovernor(actor, 'publish module registry revisions');
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw StateError(
        'Registry publish reason must be at least 10 characters.',
      );
    }

    final familyRef = _families.doc(registryModuleId);
    await _ensureLatestPublishedPointers(
      registryModuleId: registryModuleId,
      actor: actor,
    );

    late ModuleRegistryRevision published;
    await _firestore.runTransaction((txn) async {
      final revisionRef = _revisions(registryModuleId).doc(revisionId);
      final familySnap = await txn.get(familyRef);
      final revisionSnap = await txn.get(revisionRef);
      if (!familySnap.exists || !revisionSnap.exists) {
        throw StateError('Registry draft not found.');
      }

      final family = ModuleRegistryFamily.fromMap(
        familySnap.data()!,
        familySnap.id,
      );
      final revision = ModuleRegistryRevision.fromMap(
        revisionSnap.data()!,
        revisionSnap.id,
      );
      if (!family.isActive) {
        throw StateError(
          'Only active registry families can publish revisions.',
        );
      }
      if (!revision.isDraft) {
        throw StateError('Only draft registry revisions can be published.');
      }

      ModuleRegistryRevision? latestPublished;
      if (family.latestPublishedRevisionNumber > 0) {
        final latestPublishedRevisionId =
            family.latestPublishedRevisionId?.trim();
        final pinnedHash = family.latestPublishedContentHash?.trim();
        if (latestPublishedRevisionId == null ||
            latestPublishedRevisionId.isEmpty ||
            pinnedHash == null ||
            pinnedHash.isEmpty) {
          throw StateError(
            'Registry latest-published pointers are incomplete. Reload and retry after metadata repair.',
          );
        }

        final latestSnap = await txn.get(
          _revisions(registryModuleId).doc(latestPublishedRevisionId),
        );
        if (!latestSnap.exists) {
          throw StateError(
            'Registry latest-published pointer is broken. Repair governance metadata before publishing.',
          );
        }
        latestPublished = ModuleRegistryRevision.fromMap(
          latestSnap.data()!,
          latestSnap.id,
        );
        if (latestPublished.revisionNumber !=
                family.latestPublishedRevisionNumber ||
            (!latestPublished.isPublished && !latestPublished.isRetired) ||
            pinnedHash != latestPublished.contentHash) {
          throw StateError(
            'Registry latest-published metadata is inconsistent. Repair it before publishing.',
          );
        }
        if (latestPublished.contentHash == revision.contentHash) {
          throw StateError(
            'No-op registry publication rejected: candidate hash '
            '${revision.contentHash} matches latest published revision '
            '${latestPublished.revisionNumber}. Change governed content before publishing.',
          );
        }
      }

      final beforeHash = revision.contentHash;
      final nextRevisionNumber = family.latestPublishedRevisionNumber + 1;
      final now = DateTime.now();
      revision.publish(
        actor: actor,
        revisionNumber: nextRevisionNumber,
        now: now,
      );
      family
        ..refreshFromModule(revision.toComposerModuleDraft(), actor, now: now)
        ..latestPublishedRevisionNumber = nextRevisionNumber
        ..latestPublishedRevisionId = revision.revisionId
        ..latestPublishedContentHash = revision.contentHash;

      final audit = _audit(
        registryModuleId: registryModuleId,
        revisionId: revisionId,
        revisionNumber: nextRevisionNumber,
        action: ModuleRegistryAuditAction.revisionPublished,
        actor: actor,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: revision.contentHash,
        lineage: jsonDecode(revision.lineageJson) as Map<String, dynamic>,
      );

      txn.update(familyRef, family.toMap());
      txn.update(revisionRef, revision.toMap());
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
      published = revision;
    });
    return published;
  }

  Future<void> retirePublishedRevision({
    required ModuleRegistryRevision revision,
    required AppUser actor,
    required String reason,
  }) async {
    _requireRegistryGovernor(actor, 'retire module registry revisions');
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw StateError(
        'Registry retire reason must be at least 10 characters.',
      );
    }
    await _firestore.runTransaction((txn) async {
      final revisionRef = _revisions(
        revision.registryModuleId,
      ).doc(revision.revisionId);
      final revisionSnap = await txn.get(revisionRef);
      if (!revisionSnap.exists) {
        throw StateError('Registry revision not found.');
      }
      final current = ModuleRegistryRevision.fromMap(
        revisionSnap.data()!,
        revisionSnap.id,
      );
      final beforeHash = current.contentHash;
      final now = DateTime.now();
      current.retire(actor: actor, reason: trimmedReason, now: now);
      final audit = _audit(
        registryModuleId: current.registryModuleId,
        revisionId: current.revisionId,
        revisionNumber: current.revisionNumber,
        action: ModuleRegistryAuditAction.revisionRetired,
        actor: actor,
        reason: trimmedReason,
        beforeHash: beforeHash,
        afterHash: current.contentHash,
        now: now,
      );
      txn.update(revisionRef, current.toMap());
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
    });
  }

  Future<void> retireFamily({
    required ModuleRegistryFamily family,
    required AppUser actor,
    required String reason,
  }) async {
    _requireRegistryGovernor(actor, 'retire module registry families');
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw StateError(
        'Registry family retire reason must be at least 10 characters.',
      );
    }
    await _firestore.runTransaction((txn) async {
      final familyRef = _families.doc(family.registryModuleId);
      final familySnap = await txn.get(familyRef);
      if (!familySnap.exists) {
        throw StateError('Registry family not found.');
      }
      final current = ModuleRegistryFamily.fromMap(
        familySnap.data()!,
        familySnap.id,
      );
      final now = DateTime.now();
      current.retire(actor: actor, reason: trimmedReason, now: now);

      final audit = _audit(
        registryModuleId: current.registryModuleId,
        action: ModuleRegistryAuditAction.familyRetired,
        actor: actor,
        reason: trimmedReason,
        now: now,
      );
      txn.update(familyRef, current.toMap());
      txn.set(_audits.doc(audit.firestoreId), audit.toMap());
    });
  }

  Future<List<ModuleRegistryRevision>> getDraftRevisions({
    int limit = 100,
  }) async {
    final familySnap =
        await _families
            .where('status', isEqualTo: ModuleRegistryFamilyStatus.active.name)
            .limit(limit)
            .get();

    final drafts = <ModuleRegistryRevision>[];
    for (final familyDoc in familySnap.docs) {
      if (drafts.length >= limit) {
        break;
      }
      final family = ModuleRegistryFamily.fromMap(
        familyDoc.data(),
        familyDoc.id,
      );
      if (!family.isActive || family.isDeleted) {
        continue;
      }

      final revisionSnap =
          await _revisions(family.registryModuleId)
              .where(
                'revisionStatus',
                isEqualTo: ModuleRegistryRevisionStatus.draft.name,
              )
              .limit(limit - drafts.length)
              .get();

      for (final revisionDoc in revisionSnap.docs) {
        final revision = ModuleRegistryRevision.fromMap(
          revisionDoc.data(),
          revisionDoc.id,
        );
        if (revision.isDeleted || !revision.isDraft) {
          continue;
        }
        drafts.add(revision);
      }
    }

    drafts.sort((a, b) {
      final updatedCompare = (b.updatedAt ??
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
            a.updatedAt ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return a.registryModuleId.compareTo(b.registryModuleId);
    });
    return drafts.take(limit).toList(growable: false);
  }

  Future<List<PublishedRegistryModuleSource>> getPublishedSources({
    int limit = 100,
  }) async {
    final familySnap =
        await _families
            .where('status', isEqualTo: ModuleRegistryFamilyStatus.active.name)
            .limit(limit)
            .get();

    final sources = <PublishedRegistryModuleSource>[];
    for (final familyDoc in familySnap.docs) {
      if (sources.length >= limit) {
        break;
      }
      final family = ModuleRegistryFamily.fromMap(
        familyDoc.data(),
        familyDoc.id,
      );
      if (!family.isActive || family.isDeleted) {
        continue;
      }

      final revisionSnap =
          await _revisions(family.registryModuleId)
              .where(
                'revisionStatus',
                isEqualTo: ModuleRegistryRevisionStatus.published.name,
              )
              .limit(limit - sources.length)
              .get();

      for (final revisionDoc in revisionSnap.docs) {
        final revision = ModuleRegistryRevision.fromMap(
          revisionDoc.data(),
          revisionDoc.id,
        );
        if (revision.isDeleted || !revision.isPublished) {
          continue;
        }
        sources.add(
          PublishedRegistryModuleSource(family: family, revision: revision),
        );
      }
    }

    sources.sort((a, b) {
      final publishedCompare = (b.revision.publishedAt ??
              DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
            a.revision.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
      if (publishedCompare != 0) {
        return publishedCompare;
      }
      return a.module.moduleCode.compareTo(b.module.moduleCode);
    });
    return sources.take(limit).toList(growable: false);
  }

  ModuleRegistryAudit _audit({
    required String registryModuleId,
    String? revisionId,
    int? revisionNumber,
    required ModuleRegistryAuditAction action,
    required AppUser actor,
    String? reason,
    String? beforeHash,
    String? afterHash,
    Map<String, dynamic>? lineage,
    DateTime? now,
  }) {
    return ModuleRegistryAudit(
      firestoreId: _newAuditFirestoreId(),
      registryModuleId: registryModuleId,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      action: action,
      performedByUid: actor.uid,
      performedByName: actor.name,
      performedAt: now ?? DateTime.now(),
      reasonNotes: reason,
      beforeHash: beforeHash,
      afterHash: afterHash,
      lineageSummaryJson: lineage == null ? null : _prettyJson.convert(lineage),
    );
  }
}

final moduleRegistryRepositoryProvider = Provider<ModuleRegistryRepository>((
  ref,
) {
  return ModuleRegistryRepository();
});

final registryDraftRevisionsProvider =
    FutureProvider<List<ModuleRegistryRevision>>((ref) {
      return ref.watch(moduleRegistryRepositoryProvider).getDraftRevisions();
    });

final publishedRegistryModuleSourcesProvider =
    FutureProvider<List<PublishedRegistryModuleSource>>((ref) {
      return ref.watch(moduleRegistryRepositoryProvider).getPublishedSources();
    });
