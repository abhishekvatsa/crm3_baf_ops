// FILE: lib/features/planned_maintenance/domain/module_composer_validator.dart

import 'module_composer_models.dart';
import 'module_workshop_merge.dart';
import '../../maintenance/data/maintenance_model.dart';

class ModuleComposerValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final List<String> justificationsRequired;

  const ModuleComposerValidationResult({
    required this.errors,
    required this.warnings,
    required this.justificationsRequired,
  });

  bool get canSave => errors.isEmpty && justificationsRequired.isEmpty;
}

class ModuleComposerValidator {
  ModuleComposerValidator._();

  static ModuleComposerValidationResult validate(TemplateComposerDraft draft) {
    final errors = <String>[];
    final warnings = <String>[];
    final justifications = <String>[];

    if (draft.title.trim().isEmpty) {
      errors.add('Template title is required.');
    }
    if (draft.modules.isEmpty) {
      errors.add('Add at least one module before saving to publisher.');
    }
    if (draft.assetType == AssetType.governedCustom &&
        draft.assetHierarchyRefJson == null) {
      errors.add(
        'Select a governed asset class and hierarchy definition for this custom template.',
      );
    }

    final moduleCodes = <String>{};
    for (final module in draft.modules) {
      final code = module.moduleCode.trim();
      if (code.isEmpty) {
        errors.add('Every module must have a module code.');
      } else if (!moduleCodes.add(code.toLowerCase())) {
        errors.add('Duplicate module code: $code.');
      }
      if (module.title.trim().isEmpty) {
        errors.add('Module $code must have a title.');
      }
      if (hasUnresolvedMergeConflicts(module)) {
        errors.add(
          'Module $code has unresolved merge conflicts. Open the focused editor and explicitly resolve the merge workspace before saving to publisher.',
        );
      }
      if (module.discipline.name == 'shared' &&
          module.ownerDisciplines.isEmpty) {
        warnings.add('Shared module $code has no owner disciplines.');
      }
      if (module.requiredForClosure && !draft.closureReviewConfirmed) {
        justifications.add(
          'Closure-critical modules require Admin/SI review confirmation.',
        );
      }
      if (module.sourceReadiness == ComposerReadiness.consultRequired &&
          module.requiredForClosure) {
        justifications.add(
          'Module $code was cloned from a consult-required knowledge row. Confirm before closure-critical use.',
        );
      }
      if (module.sourceReadiness == ComposerReadiness.futureIntegration &&
          module.requiredForClosure) {
        justifications.add(
          'Module $code is future-integration-ready. Confirm active plant applicability before closure-critical use.',
        );
      }

      final fieldKeys = <String>{};
      for (final field in module.fields) {
        if (field.key.trim().isEmpty) {
          errors.add('Module $code has a field without a key.');
        } else if (!fieldKeys.add(field.key.trim().toLowerCase())) {
          errors.add('Module $code has duplicate field key: ${field.key}.');
        }
      }
      if (module.requiredForClosure &&
          !module.fields.any((field) => field.isRequired)) {
        warnings.add('Closure-critical module $code has no required fields.');
      }
      final safetyText = module.safetyClasses.join(' ').toLowerCase();
      if (safetyText.contains('gas') &&
          !module.fields.any(_hasLeakTightShutoffEvidence)) {
        warnings.add(
          'Gas-risk module $code needs a leak-tight shutoff confirmation '
          'field. Set Evidence role to '
          '"${composerEvidenceRoleLabel(ComposerEvidenceRole.leakTightShutoffConfirmation)}" '
          '(preferred), or use technical key '
          '"$kLeakTightShutoffEvidenceFieldKey" for legacy compatibility.',
        );
      }
      if (safetyText.contains('loto') &&
          !module.operationalStatePreconditions
              .join(' ')
              .toLowerCase()
              .contains('loto')) {
        warnings.add(
          'LOTO-related module $code has no LOTO precondition text.',
        );
      }
    }

    return ModuleComposerValidationResult(
      errors: errors,
      warnings: warnings.toSet().toList(),
      justificationsRequired: justifications,
    );
  }
}

bool _hasLeakTightShutoffEvidence(ComposerFieldDraft field) {
  if (field.evidenceRole == ComposerEvidenceRole.leakTightShutoffConfirmation) {
    return true;
  }

  // Backward compatibility: existing published/draft snapshots may carry only
  // the historical semantic technical key. Keep accepting those records while
  // new authoring prefers the structured role above.
  final legacyKey = field.key.trim().toLowerCase();
  return legacyKey.contains('leak') ||
      legacyKey.contains('shutoff') ||
      legacyKey.contains('tight');
}
