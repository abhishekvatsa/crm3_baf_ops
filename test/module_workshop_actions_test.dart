import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('duplicateComposerModule', () {
    test('deep-clones module fields, checklist items, and metadata', () {
      final source = _module(
        moduleCode: 'BASE-FAN-VIB',
        title: 'Base fan vibration check',
      );

      final copy = duplicateComposerModule(
        source: source,
        existingModules: [source],
        now: DateTime.utc(2026, 5, 19, 12, 30),
      );

      expect(copy.localId, isNot(source.localId));
      expect(copy.moduleCode, 'BASE-FAN-VIB-COPY');
      expect(copy.title, 'Base fan vibration check (copy)');
      expect(copy.metadata['duplicatedFromModuleCode'], 'BASE-FAN-VIB');
      expect(copy.metadata['duplicatedFromLocalId'], source.localId);
      expect(copy.metadata['duplicatedAt'], '2026-05-19T12:30:00.000Z');

      expect(copy.fields.single.key, source.fields.single.key);
      expect(copy.fields.single.order, source.fields.single.order);
      expect(copy.fields.single, isNot(same(source.fields.single)));
      expect(
        copy.fields.single.options,
        isNot(same(source.fields.single.options)),
      );
      expect(
        copy.fields.single.validation,
        isNot(same(source.fields.single.validation)),
      );
      expect(copy.fields.single.meta, isNot(same(source.fields.single.meta)));

      expect(
        copy.checklistItems.single,
        isNot(same(source.checklistItems.single)),
      );
      expect(copy.checklistItems.single.id, 'BASE-FAN-VIB-COPY-item-1');
      expect(
        copy.checklistItems.single.order,
        source.checklistItems.single.order,
      );
      expect(
        copy.checklistItems.single.metadata['duplicatedFromChecklistItemId'],
        'BASE-FAN-VIB-item-1',
      );

      copy.fields.single.options.add('critical');
      copy.fields.single.validation['max'] = 100;
      (copy.fields.single.meta['nested'] as Map<String, dynamic>)['changed'] =
          true;
      copy.checklistItems.single.safetyClasses.add('copied');
      (copy.metadata['nested'] as Map<String, dynamic>)['changed'] = true;

      expect(source.fields.single.options, ['normal', 'warning']);
      expect(source.fields.single.validation['max'], 50);
      expect(
        (source.fields.single.meta['nested']
            as Map<String, dynamic>)['changed'],
        isFalse,
      );
      expect(source.checklistItems.single.safetyClasses, ['normal']);
      expect(
        (source.metadata['nested'] as Map<String, dynamic>)['changed'],
        isFalse,
      );
    });

    test('increments duplicate module code when copy code already exists', () {
      final source = _module(moduleCode: 'PSL13-CLAMP', title: 'Clamp check');
      final existingCopy = _module(
        moduleCode: 'PSL13-CLAMP-COPY',
        title: 'Clamp check copy',
      );

      final copy = duplicateComposerModule(
        source: source,
        existingModules: [source, existingCopy],
        now: DateTime.utc(2026, 5, 19),
      );

      expect(copy.moduleCode, 'PSL13-CLAMP-COPY-2');
    });

    test('keeps field keys unchanged inside copied module', () {
      final source = _module(moduleCode: 'BF-01', title: 'Fan check');

      final copy = duplicateComposerModule(
        source: source,
        existingModules: [source],
        now: DateTime.utc(2026, 5, 19),
      );

      expect(copy.fields.single.key, 'vibration_mm_s');
      expect(copy.checklistItems.single.linkedFieldKey, 'vibration_mm_s');
    });

    test('normalizes blank checklist ids and zero order while duplicating', () {
      final source = _module(
        moduleCode: 'PSL13-CLAMP',
        title: 'Clamp check',
        checklistId: '',
        checklistOrder: 0,
      );

      final copy = duplicateComposerModule(
        source: source,
        existingModules: [source],
        now: DateTime.utc(2026, 5, 19),
      );

      expect(copy.checklistItems.single.id, 'PSL13-CLAMP-COPY-item-1');
      expect(copy.checklistItems.single.order, 1);
    });

    test('keeps copied checklist ids unique inside the duplicated module', () {
      final source = _module(
        moduleCode: 'BF-01',
        title: 'Fan check',
        extraChecklistItemWithSameId: true,
      );

      final copy = duplicateComposerModule(
        source: source,
        existingModules: [source],
        now: DateTime.utc(2026, 5, 19),
      );

      expect(copy.checklistItems.map((item) => item.id), [
        'BF-01-COPY-item-1',
        'BF-01-COPY-item-1-2',
      ]);
    });
  });

  group('cloneComposerModuleDraft', () {
    test(
      'creates an isolated working copy without changing module identity',
      () {
        final source = _module(
          moduleCode: 'BASE-FAN-VIB',
          title: 'Base fan vibration check',
        );

        final workingCopy = cloneComposerModuleDraft(source);

        expect(workingCopy.localId, source.localId);
        expect(workingCopy.moduleCode, source.moduleCode);
        expect(workingCopy.title, source.title);
        expect(workingCopy.fields.single, isNot(same(source.fields.single)));
        expect(
          workingCopy.checklistItems.single,
          isNot(same(source.checklistItems.single)),
        );
        expect(workingCopy.metadata, isNot(same(source.metadata)));

        workingCopy.title = 'Edited in focused editor';
        workingCopy.fields.single.label = 'Edited label';
        workingCopy.fields.single.options.add('critical');
        workingCopy.checklistItems.single.title = 'Edited checklist';
        (workingCopy.metadata['nested'] as Map<String, dynamic>)['changed'] =
            true;

        expect(source.title, 'Base fan vibration check');
        expect(source.fields.single.label, 'Vibration reading');
        expect(source.fields.single.options, ['normal', 'warning']);
        expect(source.checklistItems.single.title, 'Verify HMI trend');
        expect(
          (source.metadata['nested'] as Map<String, dynamic>)['changed'],
          isFalse,
        );
      },
    );
  });
}

ComposerModuleDraft _module({
  required String moduleCode,
  required String title,
  String? checklistId,
  int checklistOrder = 7,
  bool extraChecklistItemWithSameId = false,
}) {
  final firstChecklistId = checklistId ?? '$moduleCode-item-1';
  return ComposerModuleDraft(
    localId: 'local-$moduleCode',
    moduleCode: moduleCode,
    title: title,
    description: 'Capture HMI vibration reading.',
    assetType: AssetType.base,
    discipline: JobModuleDiscipline.shared,
    ownerDisciplines: ['instrumentation', 'mechanical'],
    primaryOwner: 'mechanical',
    requiresJointReview: true,
    useMode: JobModuleUseMode.scheduledPM,
    functionalSection: 'Base fan',
    componentGroup: 'Fan',
    subsystem: 'Cooling',
    safetyClasses: ['normal'],
    targetRefs: ['baseFan'],
    deviceTagRefs: ['VT-BF-01'],
    procedureRefs: ['SOP-BAF-FAN'],
    partRefs: ['bearing'],
    operationalStatePreconditions: ['Fan running'],
    requiredForClosure: true,
    frequency: MaintenanceFrequency.everyCharge,
    fields: [
      ComposerFieldDraft(
        key: 'vibration_mm_s',
        label: 'Vibration reading',
        type: ComposerFieldType.number,
        isRequired: true,
        order: 5,
        unit: 'mm/s',
        options: ['normal', 'warning'],
        instructionText: 'Read VT value from HMI.',
        validation: {'min': 0, 'max': 50},
        meta: {
          'source': 'test',
          'nested': {'changed': false},
        },
        isSafetyCriticalPreset: true,
        sourcePresetId: 'preset-vibration',
      ),
    ],
    checklistItems: [
      ComposerChecklistItemDraft(
        id: firstChecklistId,
        title: 'Verify HMI trend',
        description: 'Check trend before closure.',
        isRequired: true,
        order: checklistOrder,
        linkedFieldKey: 'vibration_mm_s',
        safetyClasses: ['normal'],
        metadata: {'source': 'test'},
      ),
      if (extraChecklistItemWithSameId)
        ComposerChecklistItemDraft(
          id: firstChecklistId,
          title: 'Verify HMI alarm history',
          description: 'Check alarm history before closure.',
          isRequired: true,
          order: checklistOrder + 1,
          linkedFieldKey: 'vibration_mm_s',
          safetyClasses: ['normal'],
          metadata: {'source': 'test'},
        ),
    ],
    sourceManualRef: 'BAF Manual',
    sourceKnowledgeId: 'knowledge-1',
    sourceSeedCode: 'seed-1',
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    authoringNotes: 'Review before publish.',
    metadata: {
      'source': 'test',
      'nested': {'changed': false},
    },
  );
}
