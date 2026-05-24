// FILE: lib/features/planned_maintenance/domain/knowledge_governance_diff.dart
//
// Phase 5E — Pure-dart diff between an existing `BafKnowledgeRow` and a
// proposed `KnowledgeRowDraft`. Used by the Knowledge Governance editor to
// surface a before/after summary in the change-reason dialog and to write
// a structured diff into the audit log.

import '../data/baf_knowledge_model.dart';
import 'knowledge_governance_models.dart';

class KnowledgeGovernanceDiff {
  KnowledgeGovernanceDiff._();

  static const _trackedScalarFields = <String>[
    'taskText',
    'moduleCandidateCode',
    'assetFamily',
    'functionalSection',
    'componentGroup',
    'taskType',
    'frequency',
    'discipline',
    'requiredForClosure',
    'resolverImpact',
    'composerReadiness',
    'confidence',
    'consultQuestion',
    'sourceManual',
    'sourcePage',
    'sourceType',
    'lifecycleStatus',
    'matrixVersion',
  ];

  static const _trackedListFields = <String>[
    'ownerDisciplines',
    'safetyClasses',
    'procedureRefs',
    'partRefs',
    'deviceTags',
    'targetRefs',
    'suggestedFields',
  ];

  /// Compute a structured diff. The diff is order-insensitive for list
  /// fields (set membership) which matches how the Composer and resolver
  /// consume those values.
  static KnowledgeRowDiff between({
    required BafKnowledgeRow? before,
    required KnowledgeRowDraft after,
  }) {
    final entries = <KnowledgeRowFieldDiff>[];

    if (before == null) {
      // Pure create: every populated field is "added".
      for (final field in _trackedScalarFields) {
        final afterValue = _scalarOf(after, field);
        if (_isEmpty(afterValue)) continue;
        entries.add(KnowledgeRowFieldDiff(
          field: field,
          before: null,
          after: afterValue,
          kind: KnowledgeFieldDiffKind.added,
        ));
      }
      for (final field in _trackedListFields) {
        final afterList = _listOf(after, field);
        if (afterList.isEmpty) continue;
        entries.add(KnowledgeRowFieldDiff(
          field: field,
          before: const <String>[],
          after: afterList,
          kind: KnowledgeFieldDiffKind.added,
        ));
      }
      return KnowledgeRowDiff(
        rowCode: after.rowCode,
        entries: entries,
        beforeVersion: 0,
        afterVersion: 1,
      );
    }

    for (final field in _trackedScalarFields) {
      final beforeValue = _scalarOfRow(before, field);
      final afterValue = _scalarOf(after, field);
      if (_normaliseScalar(beforeValue) == _normaliseScalar(afterValue)) continue;
      if (_isEmpty(beforeValue) && !_isEmpty(afterValue)) {
        entries.add(KnowledgeRowFieldDiff(
          field: field,
          before: null,
          after: afterValue,
          kind: KnowledgeFieldDiffKind.added,
        ));
      } else if (!_isEmpty(beforeValue) && _isEmpty(afterValue)) {
        entries.add(KnowledgeRowFieldDiff(
          field: field,
          before: beforeValue,
          after: null,
          kind: KnowledgeFieldDiffKind.removed,
        ));
      } else {
        entries.add(KnowledgeRowFieldDiff(
          field: field,
          before: beforeValue,
          after: afterValue,
          kind: KnowledgeFieldDiffKind.changed,
        ));
      }
    }

    for (final field in _trackedListFields) {
      final beforeList = _listOfRow(before, field);
      final afterList = _listOf(after, field);
      final added = afterList.where((value) => !beforeList.contains(value)).toList();
      final removed = beforeList.where((value) => !afterList.contains(value)).toList();
      if (added.isEmpty && removed.isEmpty) continue;
      entries.add(KnowledgeRowFieldDiff(
        field: field,
        before: beforeList,
        after: afterList,
        kind: removed.isEmpty
            ? KnowledgeFieldDiffKind.added
            : added.isEmpty
                ? KnowledgeFieldDiffKind.removed
                : KnowledgeFieldDiffKind.changed,
      ));
    }

    return KnowledgeRowDiff(
      rowCode: after.rowCode,
      entries: entries,
      beforeVersion: before.version,
      afterVersion: before.version + 1,
    );
  }

  /// Render a compact human-readable summary of the diff for the UI.
  /// Each line has the form `field: before → after`.
  static List<String> summarise(KnowledgeRowDiff diff) {
    return diff.entries.map((entry) {
      final before = _renderForSummary(entry.before);
      final after = _renderForSummary(entry.after);
      return '${entry.field}: $before → $after';
    }).toList();
  }

  static String _renderForSummary(Object? value) {
    if (value == null) return '∅';
    if (value is List) {
      if (value.isEmpty) return '[]';
      return '[${value.join(', ')}]';
    }
    final text = value.toString();
    if (text.isEmpty) return '∅';
    if (text.length > 80) return '${text.substring(0, 77)}…';
    return text;
  }

  static Object? _scalarOf(KnowledgeRowDraft draft, String field) {
    switch (field) {
      case 'taskText':
        return draft.taskText;
      case 'moduleCandidateCode':
        return draft.moduleCandidateCode;
      case 'assetFamily':
        return draft.assetFamily;
      case 'functionalSection':
        return draft.functionalSection;
      case 'componentGroup':
        return draft.componentGroup;
      case 'taskType':
        return draft.taskType;
      case 'frequency':
        return draft.frequency;
      case 'discipline':
        return draft.discipline;
      case 'requiredForClosure':
        return draft.requiredForClosure;
      case 'resolverImpact':
        return draft.resolverImpact;
      case 'composerReadiness':
        return draft.composerReadiness.name;
      case 'confidence':
        return draft.confidence.name;
      case 'consultQuestion':
        return draft.consultQuestion;
      case 'sourceManual':
        return draft.sourceManual;
      case 'sourcePage':
        return draft.sourcePage;
      case 'sourceType':
        return draft.sourceType;
      case 'lifecycleStatus':
        return draft.lifecycleStatus.name;
      case 'matrixVersion':
        return draft.matrixVersion;
    }
    return null;
  }

  static Object? _scalarOfRow(BafKnowledgeRow row, String field) {
    switch (field) {
      case 'taskText':
        return row.taskText;
      case 'moduleCandidateCode':
        return row.moduleCandidateCode;
      case 'assetFamily':
        return row.assetFamily;
      case 'functionalSection':
        return row.functionalSection;
      case 'componentGroup':
        return row.componentGroup;
      case 'taskType':
        return row.taskType;
      case 'frequency':
        return row.frequency;
      case 'discipline':
        return row.discipline;
      case 'requiredForClosure':
        return row.requiredForClosure;
      case 'resolverImpact':
        return row.resolverImpact;
      case 'composerReadiness':
        return row.composerReadiness;
      case 'confidence':
        return row.confidence;
      case 'consultQuestion':
        return row.consultQuestion;
      case 'sourceManual':
        return row.sourceManual;
      case 'sourcePage':
        return row.sourcePage;
      case 'sourceType':
        return row.sourceType;
      case 'lifecycleStatus':
        return row.lifecycleStatus;
      case 'matrixVersion':
        return row.matrixVersion;
    }
    return null;
  }

  static List<String> _listOf(KnowledgeRowDraft draft, String field) {
    switch (field) {
      case 'ownerDisciplines':
        return List<String>.from(draft.ownerDisciplines)..sort();
      case 'safetyClasses':
        return List<String>.from(draft.safetyClasses)..sort();
      case 'procedureRefs':
        return List<String>.from(draft.procedureRefs)..sort();
      case 'partRefs':
        return List<String>.from(draft.partRefs)..sort();
      case 'deviceTags':
        return List<String>.from(draft.deviceTags.map((t) => t.toUpperCase()))..sort();
      case 'targetRefs':
        return List<String>.from(draft.targetRefs)..sort();
      case 'suggestedFields':
        return List<String>.from(draft.suggestedFields)..sort();
    }
    return const <String>[];
  }

  static List<String> _listOfRow(BafKnowledgeRow row, String field) {
    switch (field) {
      case 'ownerDisciplines':
        return List<String>.from(row.ownerDisciplines)..sort();
      case 'safetyClasses':
        return List<String>.from(row.safetyClasses)..sort();
      case 'procedureRefs':
        return List<String>.from(row.procedureRefs)..sort();
      case 'partRefs':
        return List<String>.from(row.partRefs)..sort();
      case 'deviceTags':
        return List<String>.from(row.deviceTags.map((t) => t.toUpperCase()))..sort();
      case 'targetRefs':
        return List<String>.from(row.targetRefs)..sort();
      case 'suggestedFields':
        return List<String>.from(row.suggestedFields)..sort();
    }
    return const <String>[];
  }

  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  static String _normaliseScalar(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}
