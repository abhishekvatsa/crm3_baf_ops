// FILE: lib/features/planned_maintenance/domain/knowledge_correction_promoter.dart
//
// Phase 5E — Promote tag-resolver corrections into governed knowledge rows.
//
// During module composition, operators occasionally hand-correct a tag the
// resolver could not infer. Those corrections are persisted on the published
// template version in the `composer.tagResolverCorrections` block of
// `jobTemplateSnapshotJson`. This module reads those entries and turns
// them into draft `BafKnowledgeRow`-shaped governance candidates so an
// Admin/SI operator can review and promote each one (or a batch) into the
// formal `knowledge_base` collection.

import 'dart:convert';

import '../data/baf_knowledge_model.dart';
import 'baf_knowledge_layer.dart';
import 'baf_tag_resolver_v2.dart';
import 'knowledge_governance_models.dart';
import 'module_composer_models.dart';

/// One promotable correction harvested from a published template version.
class PromotableTagCorrection {
  final String rawInput;
  final String normalizedTag;
  final String resolvedComponent;
  final String correctionStatus;
  final String sourceTemplateVersionId;
  final String sourceTemplatePackageCode;
  final int sourceTemplateVersionNumber;
  final DateTime harvestedAt;
  final BafTagResolution? resolverHint;
  final BafKnowledgeRow? alreadyPromotedTo;

  const PromotableTagCorrection({
    required this.rawInput,
    required this.normalizedTag,
    required this.resolvedComponent,
    required this.correctionStatus,
    required this.sourceTemplateVersionId,
    required this.sourceTemplatePackageCode,
    required this.sourceTemplateVersionNumber,
    required this.harvestedAt,
    this.resolverHint,
    this.alreadyPromotedTo,
  });

  bool get isAlreadyPromoted => alreadyPromotedTo != null;

  /// Synthesise a knowledge row code for promotion. The shape mirrors the
  /// existing `TAG-<NORMALISED>` convention used by the static fallback so
  /// the promoted row appears alongside the embedded baseline tag rows.
  String get suggestedRowCode {
    if (normalizedTag.isEmpty) return 'TAG-UNKNOWN';
    return 'TAG-$normalizedTag';
  }
}

class KnowledgeCorrectionPromoter {
  KnowledgeCorrectionPromoter._();

  /// Extract every promotable correction from a published template version's
  /// `jobTemplateSnapshotJson`. Unknown shapes return an empty list rather
  /// than throwing — the caller is robust to legacy templates that pre-date
  /// the Composer.
  static List<PromotableTagCorrection> harvestFromTemplateSnapshot({
    required String jobTemplateSnapshotJson,
    required String sourceTemplateVersionId,
    required String sourceTemplatePackageCode,
    required int sourceTemplateVersionNumber,
    required DateTime harvestedAt,
    Map<String, BafKnowledgeRow>? existingRowsByCode,
  }) {
    if (jobTemplateSnapshotJson.trim().isEmpty) {
      return const <PromotableTagCorrection>[];
    }
    Map<String, dynamic> snapshot;
    try {
      final decoded = jsonDecode(jobTemplateSnapshotJson);
      if (decoded is! Map<String, dynamic>) return const <PromotableTagCorrection>[];
      snapshot = decoded;
    } catch (_) {
      return const <PromotableTagCorrection>[];
    }
    final composer = snapshot['composer'];
    if (composer is! Map<String, dynamic>) return const <PromotableTagCorrection>[];
    final rawCorrections = composer['tagResolverCorrections'];
    if (rawCorrections is! List) return const <PromotableTagCorrection>[];

    final results = <PromotableTagCorrection>[];
    for (final raw in rawCorrections) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final rawInput = (map['rawInput'] ?? '').toString().trim();
      final normalizedTag = ((map['normalizedTag'] ?? '').toString()).trim().toUpperCase();
      final resolvedComponent = (map['resolvedComponent'] ?? '').toString().trim();
      final status = (map['status'] ?? 'approvedForThisVersion').toString().trim();
      if (normalizedTag.isEmpty && rawInput.isEmpty) continue;
      final hint = BafTagResolverV2.resolve(rawInput.isEmpty ? normalizedTag : rawInput);
      final candidateCode = normalizedTag.isEmpty ? 'TAG-UNKNOWN' : 'TAG-$normalizedTag';
      final alreadyPromoted = existingRowsByCode == null
          ? null
          : existingRowsByCode[candidateCode];
      results.add(PromotableTagCorrection(
        rawInput: rawInput,
        normalizedTag: normalizedTag,
        resolvedComponent: resolvedComponent,
        correctionStatus: status,
        sourceTemplateVersionId: sourceTemplateVersionId,
        sourceTemplatePackageCode: sourceTemplatePackageCode,
        sourceTemplateVersionNumber: sourceTemplateVersionNumber,
        harvestedAt: harvestedAt,
        resolverHint: hint,
        alreadyPromotedTo: alreadyPromoted,
      ));
    }
    return results;
  }

  /// Build a `KnowledgeRowDraft` for promotion. The draft is deliberately
  /// conservative: readiness=`tagOnly`, confidence=`inferredNeedsReview`,
  /// `requiredForClosure='consult'`. The Admin/SI operator must change at
  /// least one of those before saving if the row is intended for closure.
  static KnowledgeRowDraft buildDraft(
    PromotableTagCorrection correction, {
    required String defaultMatrixVersion,
  }) {
    final hint = correction.resolverHint;
    final draft = KnowledgeRowDraft.blank(prefilledRowCode: correction.suggestedRowCode);
    draft.taskText = correction.resolvedComponent.isNotEmpty
        ? correction.resolvedComponent
        : 'Tag knowledge for ${correction.normalizedTag}';
    draft.moduleCandidateCode = correction.suggestedRowCode;
    draft.assetFamily = hint?.assetType?.name ?? '';
    draft.functionalSection = hint?.functionalSection ?? '';
    draft.componentGroup = correction.resolvedComponent;
    draft.taskType = 'tagKnowledge';
    draft.frequency = 'eventBased';
    draft.discipline = hint?.discipline?.name ?? 'instrumentation';
    draft.ownerDisciplines = List<String>.from(
      hint?.ownerDisciplines ?? const <String>['instrumentation'],
    );
    draft.safetyClasses = List<String>.from(hint?.safetyClasses ?? const <String>[]);
    draft.deviceTags = correction.normalizedTag.isEmpty
        ? <String>[]
        : <String>[correction.normalizedTag];
    draft.targetRefs = List<String>.from(hint?.hierarchyPath ?? const <String>[]);
    draft.suggestedFields = const <String>[
      'observed_value',
      'within_limit_yes_no',
      'action_taken_long_text',
    ];
    draft.requiredForClosure = 'consult';
    draft.resolverImpact = 'yes';
    draft.composerReadiness = ComposerReadiness.tagOnly;
    draft.confidence = KnowledgeConfidence.inferredNeedsReview;
    draft.consultQuestion =
        'Promoted from tag resolver correction for ${correction.rawInput.isEmpty ? correction.normalizedTag : correction.rawInput}; confirm closure ownership.';
    draft.sourceManual = 'Composer tag-resolver correction';
    draft.sourcePage = correction.sourceTemplatePackageCode.isEmpty
        ? correction.sourceTemplateVersionId
        : '${correction.sourceTemplatePackageCode} v${correction.sourceTemplateVersionNumber}';
    draft.sourceType = 'tag_resolver_correction';
    draft.lifecycleStatus = KnowledgeLifecycleStatus.active;
    draft.matrixVersion = defaultMatrixVersion.isEmpty
        ? BafKnowledgeLayer.matrixVersion
        : defaultMatrixVersion;
    return draft;
  }

  /// Convenience: harvest from many template snapshots and de-duplicate by
  /// normalised tag. The most recent harvest of a tag wins.
  static List<PromotableTagCorrection> harvestMany({
    required Iterable<HarvestableTemplateSnapshot> snapshots,
    Map<String, BafKnowledgeRow>? existingRowsByCode,
  }) {
    final byTag = <String, PromotableTagCorrection>{};
    for (final snap in snapshots) {
      final batch = harvestFromTemplateSnapshot(
        jobTemplateSnapshotJson: snap.jobTemplateSnapshotJson,
        sourceTemplateVersionId: snap.versionFirestoreId,
        sourceTemplatePackageCode: snap.packageCode,
        sourceTemplateVersionNumber: snap.versionNumber,
        harvestedAt: snap.harvestedAt,
        existingRowsByCode: existingRowsByCode,
      );
      for (final correction in batch) {
        final key = correction.normalizedTag.isEmpty
            ? correction.rawInput.toUpperCase()
            : correction.normalizedTag;
        final existing = byTag[key];
        if (existing == null || existing.harvestedAt.isBefore(correction.harvestedAt)) {
          byTag[key] = correction;
        }
      }
    }
    final results = byTag.values.toList()
      ..sort((a, b) => a.normalizedTag.compareTo(b.normalizedTag));
    return results;
  }
}

class HarvestableTemplateSnapshot {
  final String versionFirestoreId;
  final String packageCode;
  final int versionNumber;
  final String jobTemplateSnapshotJson;
  final DateTime harvestedAt;

  const HarvestableTemplateSnapshot({
    required this.versionFirestoreId,
    required this.packageCode,
    required this.versionNumber,
    required this.jobTemplateSnapshotJson,
    required this.harvestedAt,
  });
}
