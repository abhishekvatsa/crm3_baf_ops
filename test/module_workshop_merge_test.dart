import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_validator.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeComposerModulesWithConflictWorkspace', () {
    test('creates a new draft and never mutates source modules', () {
      final mechanical = _module(
        moduleCode: 'FAN-MECH',
        title: 'Mechanical fan check',
        fieldKey: 'bearing_temperature',
        discipline: JobModuleDiscipline.mechanical,
        ownerDisciplines: const ['mechanical'],
        requiredForClosure: true,
      );
      final ia = _module(
        moduleCode: 'FAN-IA',
        title: 'I&A vibration check',
        fieldKey: 'vibration_mm_s',
        discipline: JobModuleDiscipline.instrumentation,
        ownerDisciplines: const ['instrumentation'],
        requiresJointReview: true,
      );

      final merged = mergeComposerModulesWithConflictWorkspace(
        sources: [mechanical, ia],
        existingModules: [mechanical, ia],
        now: DateTime.utc(2026, 5, 20, 8),
      );

      expect(merged.localId, isNot(mechanical.localId));
      expect(merged.moduleCode, 'FAN-MECH-MERGED');
      expect(merged.discipline, JobModuleDiscipline.shared);
      expect(merged.ownerDisciplines, ['mechanical', 'instrumentation']);
      expect(merged.requiredForClosure, isTrue);
      expect(merged.requiresJointReview, isTrue);
      expect(merged.fields.map((field) => field.key), [
        'bearing_temperature',
        'vibration_mm_s',
      ]);
      expect(mechanical.fields.single.key, 'bearing_temperature');
      expect(ia.fields.single.key, 'vibration_mm_s');
      expect(hasUnresolvedMergeConflicts(merged), isFalse);
    });

    test('stages duplicate field keys in conflict workspace', () {
      final primary = _module(
        moduleCode: 'FAN-MECH',
        title: 'Mechanical fan check',
        fieldKey: 'observation',
      );
      final secondary = _module(
        moduleCode: 'FAN-OPS',
        title: 'Operations fan check',
        fieldKey: 'observation',
        discipline: JobModuleDiscipline.operations,
        ownerDisciplines: const ['operations'],
      );

      final merged = mergeComposerModulesWithConflictWorkspace(
        sources: [primary, secondary],
        existingModules: [primary, secondary],
        now: DateTime.utc(2026, 5, 20, 8),
      );

      expect(merged.fields.first.key, 'observation');
      expect(merged.fields.last.key, 'observation-merge-fan-ops');
      expect(
        merged.checklistItems.last.linkedFieldKey,
        'observation-merge-fan-ops',
      );
      expect(hasUnresolvedMergeConflicts(merged), isTrue);
      expect(unresolvedMergeConflictCount(merged), greaterThanOrEqualTo(1));
      expect(
        unresolvedMergeConflictSummaries(merged).join(' '),
        contains('Field key "observation"'),
      );
      expect(
        mergeFieldRenameSummaries(merged),
        contains('FAN-OPS: observation → observation-merge-fan-ops'),
      );
    });

    test(
      'validator blocks unresolved merge workspace until explicitly resolved',
      () {
        final primary = _module(
          moduleCode: 'FAN-MECH',
          title: 'Mechanical fan check',
          fieldKey: 'observation',
        );
        final secondary = _module(
          moduleCode: 'FAN-OPS',
          title: 'Operations fan check',
          fieldKey: 'observation',
          discipline: JobModuleDiscipline.operations,
          ownerDisciplines: const ['operations'],
        );
        final merged = mergeComposerModulesWithConflictWorkspace(
          sources: [primary, secondary],
          existingModules: [primary, secondary],
          now: DateTime.utc(2026, 5, 20, 8),
        );
        final draft = TemplateComposerDraft(
          localId: 'draft',
          title: 'Merge test template',
          assetType: AssetType.base,
          modules: [merged],
          closureReviewConfirmed: true,
        );

        final blocked = ModuleComposerValidator.validate(draft);
        expect(blocked.canSave, isFalse);
        expect(
          blocked.errors.join(' '),
          contains('unresolved merge conflicts'),
        );

        markMergeConflictsResolved(
          merged,
          resolvedAt: DateTime.utc(2026, 5, 20, 9),
        );
        final resolved = ModuleComposerValidator.validate(draft);
        expect(resolved.errors, isEmpty);
      },
    );
  });
}

ComposerModuleDraft _module({
  required String moduleCode,
  required String title,
  required String fieldKey,
  JobModuleDiscipline discipline = JobModuleDiscipline.mechanical,
  List<String> ownerDisciplines = const ['mechanical'],
  bool requiredForClosure = false,
  bool requiresJointReview = false,
}) {
  return ComposerModuleDraft(
    localId: moduleCode.toLowerCase(),
    moduleCode: moduleCode,
    title: title,
    description: '$title description',
    assetType: AssetType.base,
    discipline: discipline,
    ownerDisciplines: ownerDisciplines,
    primaryOwner: ownerDisciplines.isEmpty ? null : ownerDisciplines.first,
    requiresJointReview: requiresJointReview,
    useMode: JobModuleUseMode.scheduledPM,
    functionalSection: 'Fan',
    componentGroup: 'Base fan',
    subsystem: 'Fan health',
    safetyClasses: const ['normal'],
    targetRefs: const ['BF-01'],
    deviceTagRefs: const ['BF-01-VT'],
    procedureRefs: const ['BAF-FAN'],
    partRefs: const [],
    operationalStatePreconditions: const ['LOTO if required'],
    requiredForClosure: requiredForClosure,
    frequency: MaintenanceFrequency.everyCharge,
    fields: [
      ComposerFieldDraft(
        key: fieldKey,
        label: fieldKey,
        type: ComposerFieldType.text,
        isRequired: requiredForClosure,
        order: 1,
      ),
    ],
    checklistItems: [
      ComposerChecklistItemDraft(
        id: '$moduleCode-item-1',
        title: 'Capture $fieldKey',
        isRequired: requiredForClosure,
        order: 1,
        linkedFieldKey: fieldKey,
      ),
    ],
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    metadata: const {'source': 'test'},
  );
}
