// FILE: lib/features/planned_maintenance/domain/knowledge_governance_models.dart
//
// Phase 5E — Knowledge Governance models.
//
// These DTOs back the Knowledge Governance editor and version-history UI.
// They are deliberately UI-shaped: they wrap an underlying
// `BafKnowledgeRow`/`BafKnowledgeEntry` for read, and expose a small set of
// editable fields for write. The cloud authority remains Firestore
// `knowledge_base/{rowCode}` and the Firestore rule set in
// `firestore.rules` (`validKnowledgeBaseUpdate`).

import 'dart:convert';

import '../data/baf_knowledge_model.dart';
import 'baf_knowledge_layer.dart';
import 'module_composer_models.dart';

/// Lifecycle status of a governed knowledge row. Mirrors
/// `isKnowledgeLifecycleStatus(...)` in `firestore.rules`.
enum KnowledgeLifecycleStatus { active, retired, archived }

extension KnowledgeLifecycleStatusX on KnowledgeLifecycleStatus {
  String get name {
    switch (this) {
      case KnowledgeLifecycleStatus.active:
        return 'active';
      case KnowledgeLifecycleStatus.retired:
        return 'retired';
      case KnowledgeLifecycleStatus.archived:
        return 'archived';
    }
  }

  static KnowledgeLifecycleStatus parse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'retired':
        return KnowledgeLifecycleStatus.retired;
      case 'archived':
        return KnowledgeLifecycleStatus.archived;
      case 'active':
      default:
        return KnowledgeLifecycleStatus.active;
    }
  }
}

/// Categorical filters surfaced on the Knowledge Governance screen.
class KnowledgeGovernanceFilter {
  final String query;
  final Set<KnowledgeLifecycleStatus> lifecycleStatuses;
  final Set<ComposerReadiness> readinessStates;
  final Set<KnowledgeConfidence> confidenceStates;
  final Set<String> assetFamilies;
  final Set<String> safetyClasses;
  final bool onlyTagBearingRows;
  final bool onlyClosureCritical;
  final bool onlyUnsynced;

  const KnowledgeGovernanceFilter({
    this.query = '',
    this.lifecycleStatuses = const <KnowledgeLifecycleStatus>{
      KnowledgeLifecycleStatus.active,
    },
    this.readinessStates = const <ComposerReadiness>{},
    this.confidenceStates = const <KnowledgeConfidence>{},
    this.assetFamilies = const <String>{},
    this.safetyClasses = const <String>{},
    this.onlyTagBearingRows = false,
    this.onlyClosureCritical = false,
    this.onlyUnsynced = false,
  });

  factory KnowledgeGovernanceFilter.allActive() => const KnowledgeGovernanceFilter();

  KnowledgeGovernanceFilter copyWith({
    String? query,
    Set<KnowledgeLifecycleStatus>? lifecycleStatuses,
    Set<ComposerReadiness>? readinessStates,
    Set<KnowledgeConfidence>? confidenceStates,
    Set<String>? assetFamilies,
    Set<String>? safetyClasses,
    bool? onlyTagBearingRows,
    bool? onlyClosureCritical,
    bool? onlyUnsynced,
  }) {
    return KnowledgeGovernanceFilter(
      query: query ?? this.query,
      lifecycleStatuses: lifecycleStatuses ?? this.lifecycleStatuses,
      readinessStates: readinessStates ?? this.readinessStates,
      confidenceStates: confidenceStates ?? this.confidenceStates,
      assetFamilies: assetFamilies ?? this.assetFamilies,
      safetyClasses: safetyClasses ?? this.safetyClasses,
      onlyTagBearingRows: onlyTagBearingRows ?? this.onlyTagBearingRows,
      onlyClosureCritical: onlyClosureCritical ?? this.onlyClosureCritical,
      onlyUnsynced: onlyUnsynced ?? this.onlyUnsynced,
    );
  }

  bool get isWideOpen =>
      query.trim().isEmpty &&
      lifecycleStatuses.length == KnowledgeLifecycleStatus.values.length &&
      readinessStates.isEmpty &&
      confidenceStates.isEmpty &&
      assetFamilies.isEmpty &&
      safetyClasses.isEmpty &&
      !onlyTagBearingRows &&
      !onlyClosureCritical &&
      !onlyUnsynced;

  /// Apply the filter to a flat list of governed rows. The filter is a pure
  /// in-memory predicate; it does not perform any I/O.
  Iterable<BafKnowledgeRow> apply(Iterable<BafKnowledgeRow> rows) {
    final lower = query.trim().toLowerCase();
    return rows.where((row) {
      if (!lifecycleStatuses.contains(KnowledgeLifecycleStatusX.parse(row.lifecycleStatus))) {
        return false;
      }
      if (readinessStates.isNotEmpty &&
          !readinessStates.any((state) => state.name == row.composerReadiness)) {
        return false;
      }
      if (confidenceStates.isNotEmpty &&
          !confidenceStates.any((state) => state.name == row.confidence)) {
        return false;
      }
      if (assetFamilies.isNotEmpty &&
          !assetFamilies.any((value) => value.toLowerCase() == row.assetFamily.toLowerCase())) {
        return false;
      }
      if (safetyClasses.isNotEmpty) {
        final rowSafety = row.safetyClasses.map((s) => s.toLowerCase()).toSet();
        final wanted = safetyClasses.map((s) => s.toLowerCase()).toSet();
        if (!rowSafety.any(wanted.contains)) return false;
      }
      if (onlyTagBearingRows && row.deviceTags.isEmpty) return false;
      if (onlyClosureCritical && row.requiredForClosure != 'yes') return false;
      if (onlyUnsynced && row.isSynced) return false;

      if (lower.isEmpty) return true;
      final haystack = <String>[
        row.rowCode,
        row.taskText,
        row.componentGroup,
        row.functionalSection,
        row.assetFamily,
        row.discipline,
        row.taskType,
        row.frequency,
        row.moduleCandidateCode,
        row.consultQuestion,
        ...row.safetyClasses,
        ...row.ownerDisciplines,
        ...row.deviceTags,
        ...row.procedureRefs,
        ...row.partRefs,
        ...row.targetRefs,
      ].join(' ').toLowerCase();
      return haystack.contains(lower);
    });
  }
}

/// In-memory editor draft. Mirrors the shape of `BafKnowledgeRow` but is
/// detached from Isar; the controller materialises a `BafKnowledgeRow` only
/// when the operator presses Save.
class KnowledgeRowDraft {
  String rowCode;
  String taskText;
  String moduleCandidateCode;
  String assetFamily;
  String functionalSection;
  String componentGroup;
  String taskType;
  String frequency;
  String discipline;
  List<String> ownerDisciplines;
  List<String> safetyClasses;
  List<String> procedureRefs;
  List<String> partRefs;
  List<String> deviceTags;
  List<String> targetRefs;
  List<String> suggestedFields;
  String requiredForClosure;
  String resolverImpact;
  ComposerReadiness composerReadiness;
  KnowledgeConfidence confidence;
  String consultQuestion;
  String sourceManual;
  String sourcePage;
  String sourceType;
  KnowledgeLifecycleStatus lifecycleStatus;
  String matrixVersion;
  String changeSummary;

  KnowledgeRowDraft({
    required this.rowCode,
    required this.taskText,
    required this.moduleCandidateCode,
    required this.assetFamily,
    required this.functionalSection,
    required this.componentGroup,
    required this.taskType,
    required this.frequency,
    required this.discipline,
    required this.ownerDisciplines,
    required this.safetyClasses,
    required this.procedureRefs,
    required this.partRefs,
    required this.deviceTags,
    required this.targetRefs,
    required this.suggestedFields,
    required this.requiredForClosure,
    required this.resolverImpact,
    required this.composerReadiness,
    required this.confidence,
    required this.consultQuestion,
    required this.sourceManual,
    required this.sourcePage,
    required this.sourceType,
    required this.lifecycleStatus,
    required this.matrixVersion,
    this.changeSummary = '',
  });

  factory KnowledgeRowDraft.fromRow(BafKnowledgeRow row) {
    return KnowledgeRowDraft(
      rowCode: row.rowCode,
      taskText: row.taskText,
      moduleCandidateCode: row.moduleCandidateCode,
      assetFamily: row.assetFamily,
      functionalSection: row.functionalSection,
      componentGroup: row.componentGroup,
      taskType: row.taskType,
      frequency: row.frequency,
      discipline: row.discipline,
      ownerDisciplines: List<String>.from(row.ownerDisciplines),
      safetyClasses: List<String>.from(row.safetyClasses),
      procedureRefs: List<String>.from(row.procedureRefs),
      partRefs: List<String>.from(row.partRefs),
      deviceTags: List<String>.from(row.deviceTags),
      targetRefs: List<String>.from(row.targetRefs),
      suggestedFields: List<String>.from(row.suggestedFields),
      requiredForClosure: row.requiredForClosure,
      resolverImpact: row.resolverImpact,
      composerReadiness: _readiness(row.composerReadiness),
      confidence: _confidence(row.confidence),
      consultQuestion: row.consultQuestion,
      sourceManual: row.sourceManual,
      sourcePage: row.sourcePage,
      sourceType: row.sourceType,
      lifecycleStatus: KnowledgeLifecycleStatusX.parse(row.lifecycleStatus),
      matrixVersion: row.matrixVersion,
      changeSummary: '',
    );
  }

  /// Empty draft for "Create new row".
  factory KnowledgeRowDraft.blank({String? prefilledRowCode}) {
    return KnowledgeRowDraft(
      rowCode: prefilledRowCode ?? '',
      taskText: '',
      moduleCandidateCode: prefilledRowCode ?? '',
      assetFamily: '',
      functionalSection: '',
      componentGroup: '',
      taskType: '',
      frequency: 'unknown',
      discipline: 'mechanical',
      ownerDisciplines: <String>[],
      safetyClasses: <String>[],
      procedureRefs: <String>[],
      partRefs: <String>[],
      deviceTags: <String>[],
      targetRefs: <String>[],
      suggestedFields: <String>[],
      requiredForClosure: 'consult',
      resolverImpact: 'no',
      composerReadiness: ComposerReadiness.needsReview,
      confidence: KnowledgeConfidence.inferredNeedsReview,
      consultQuestion: '',
      sourceManual: '',
      sourcePage: '',
      sourceType: 'manual_entry',
      lifecycleStatus: KnowledgeLifecycleStatus.active,
      matrixVersion: BafKnowledgeLayer.matrixVersion,
      changeSummary: '',
    );
  }

  Map<String, dynamic> toEntryMap() => <String, dynamic>{
        'rowCode': rowCode,
        'moduleCandidateCode': moduleCandidateCode,
        'sourceManual': sourceManual,
        'sourcePage': sourcePage,
        'sourceType': sourceType,
        'assetFamily': assetFamily,
        'functionalSection': functionalSection,
        'componentGroup': componentGroup,
        'taskType': taskType,
        'taskText': taskText,
        'frequency': frequency,
        'discipline': discipline,
        'ownerDisciplines': ownerDisciplines,
        'safetyClass': safetyClasses,
        'safetyClasses': safetyClasses,
        'procedureRefs': procedureRefs,
        'partRefs': partRefs,
        'deviceTags': deviceTags.map((tag) => tag.toUpperCase()).toList(),
        'targetRefs': targetRefs,
        'suggestedFields': suggestedFields,
        'requiredForClosure': requiredForClosure,
        'resolverImpact': resolverImpact,
        'composerReadiness': composerReadiness.name,
        'confidence': confidence.name,
        'consultQuestion': consultQuestion,
        'lifecycleStatus': lifecycleStatus.name,
        'matrixVersion': matrixVersion,
      };

  /// Editor-side validation. Mirrors the structural guarantees in
  /// `validKnowledgeBaseCommon(...)` in `firestore.rules` so the operator
  /// gets local feedback before a Firestore round-trip rejects them.
  KnowledgeRowDraftValidation validateForSave({required bool isCreate}) {
    final errors = <String>[];
    final warnings = <String>[];
    final code = rowCode.trim();
    if (code.isEmpty) {
      errors.add('Row code is required.');
    } else if (!RegExp(r'^[A-Za-z0-9._-]{2,64}$').hasMatch(code)) {
      errors.add('Row code must be 2–64 characters, letters/digits/._-/.');
    }
    if (taskText.trim().isEmpty) {
      errors.add('Task text is required.');
    }
    if (moduleCandidateCode.trim().isEmpty) {
      errors.add('Module candidate code is required.');
    }
    if (matrixVersion.trim().isEmpty) {
      errors.add('Matrix version is required.');
    }
    final reason = changeSummary.trim();
    if (reason.length < 15) {
      errors.add('Change reason must be at least 15 characters.');
    }
    if (deviceTags.any((tag) => tag.trim().isEmpty)) {
      warnings.add('Empty device tag entry will be dropped on save.');
    }
    if (composerReadiness == ComposerReadiness.consultRequired &&
        requiredForClosure == 'yes') {
      warnings.add('Consult-required readiness with closure-critical flag — confirm before publish.');
    }
    if (lifecycleStatus != KnowledgeLifecycleStatus.active && isCreate) {
      errors.add('A new row must start in lifecycle state "active".');
    }
    return KnowledgeRowDraftValidation(errors: errors, warnings: warnings);
  }
}

class KnowledgeRowDraftValidation {
  final List<String> errors;
  final List<String> warnings;

  const KnowledgeRowDraftValidation({required this.errors, required this.warnings});

  bool get canSave => errors.isEmpty;
}

/// A diff entry between a prior `BafKnowledgeRow` and a `KnowledgeRowDraft`.
///
/// The diff is purely structural and order-insensitive for list fields.
class KnowledgeRowFieldDiff {
  final String field;
  final Object? before;
  final Object? after;
  final KnowledgeFieldDiffKind kind;

  const KnowledgeRowFieldDiff({
    required this.field,
    required this.before,
    required this.after,
    required this.kind,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'field': field,
        'before': before,
        'after': after,
        'kind': kind.name,
      };
}

enum KnowledgeFieldDiffKind { added, removed, changed }

class KnowledgeRowDiff {
  final String rowCode;
  final List<KnowledgeRowFieldDiff> entries;
  final int beforeVersion;
  final int afterVersion;

  const KnowledgeRowDiff({
    required this.rowCode,
    required this.entries,
    required this.beforeVersion,
    required this.afterVersion,
  });

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'rowCode': rowCode,
        'beforeVersion': beforeVersion,
        'afterVersion': afterVersion,
        'changeCount': entries.length,
        'changes': entries.map((entry) => entry.toMap()).toList(),
      };

  String toJson() => jsonEncode(toMap());
}

/// Audit-log entry for a knowledge governance action. This mirrors the
/// shape we store in Firestore `audit_logs` so the existing audit timeline
/// can render knowledge rows without a separate path.
class KnowledgeGovernanceAuditEntry {
  final String rowCode;
  final KnowledgeGovernanceAction action;
  final int versionBefore;
  final int versionAfter;
  final String performedByUid;
  final String performedByName;
  final DateTime performedAt;
  final String changeSummary;
  final KnowledgeRowDiff? diff;

  const KnowledgeGovernanceAuditEntry({
    required this.rowCode,
    required this.action,
    required this.versionBefore,
    required this.versionAfter,
    required this.performedByUid,
    required this.performedByName,
    required this.performedAt,
    required this.changeSummary,
    this.diff,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'entityType': 'knowledge_base',
        'entityId': rowCode,
        'action': action.name,
        'versionBefore': versionBefore,
        'versionAfter': versionAfter,
        'performedByUid': performedByUid,
        'performedByName': performedByName,
        'performedAt': performedAt.toIso8601String(),
        'changeSummary': changeSummary,
        if (diff != null) 'diff': diff!.toMap(),
      };
}

enum KnowledgeGovernanceAction {
  created,
  edited,
  retired,
  archived,
  restored,
  promotedFromTagCorrection,
  importedFromExternal,
}

extension KnowledgeGovernanceActionX on KnowledgeGovernanceAction {
  String get displayLabel {
    switch (this) {
      case KnowledgeGovernanceAction.created:
        return 'Created';
      case KnowledgeGovernanceAction.edited:
        return 'Edited';
      case KnowledgeGovernanceAction.retired:
        return 'Retired';
      case KnowledgeGovernanceAction.archived:
        return 'Archived';
      case KnowledgeGovernanceAction.restored:
        return 'Restored';
      case KnowledgeGovernanceAction.promotedFromTagCorrection:
        return 'Promoted from tag correction';
      case KnowledgeGovernanceAction.importedFromExternal:
        return 'Imported';
    }
  }
}

ComposerReadiness _readiness(String value) {
  for (final state in ComposerReadiness.values) {
    if (state.name == value) return state;
  }
  return ComposerReadiness.needsReview;
}

KnowledgeConfidence _confidence(String value) {
  for (final state in KnowledgeConfidence.values) {
    if (state.name == value) return state;
  }
  return KnowledgeConfidence.inferredNeedsReview;
}
