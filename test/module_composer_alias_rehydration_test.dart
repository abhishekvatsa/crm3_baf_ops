import 'dart:convert';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_json_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rehydrates fields and checklist through per-module aliases', () {
    final draft = TemplateComposerDraft.fromPayloads(
      jobTemplateSnapshotJson: jsonEncode({
        'title': 'Alias import',
        'assetType': AssetType.base.name,
      }),
      moduleSnapshotsJson: jsonEncode([
        {
          'moduleId': 'MOD-A',
          'moduleTitle': 'Alias module A',
          'discipline': JobModuleDiscipline.mechanical.name,
        },
        {
          'moduleCode': 'MOD-B',
          'moduleTitle': 'Alias module B',
          'discipline': JobModuleDiscipline.electrical.name,
        },
      ]),
      fieldDefinitionsJson: jsonEncode([
        {
          'templateModuleId': 'MOD-A',
          'key': 'field_a',
          'label': 'Field A',
          'type': ComposerFieldType.text.name,
          'order': 1,
        },
        {
          'moduleId': 'MOD-B',
          'key': 'field_b',
          'label': 'Field B',
          'type': ComposerFieldType.text.name,
          'order': 1,
        },
      ]),
      checklistJson: jsonEncode([
        {
          'parentModuleCode': 'MOD-A',
          'id': 'check_a',
          'title': 'Check A',
          'order': 1,
        },
        {
          'moduleCode': 'MOD-B',
          'id': 'check_b',
          'title': 'Check B',
          'order': 1,
        },
      ]),
    );

    expect(draft.modules, hasLength(2));
    expect(draft.modules[0].moduleCode, 'MOD-A');
    expect(draft.modules[0].fields.single.key, 'field_a');
    expect(draft.modules[0].checklistItems.single.id, 'check_a');
    expect(draft.modules[1].moduleCode, 'MOD-B');
    expect(draft.modules[1].fields.single.key, 'field_b');
    expect(draft.modules[1].checklistItems.single.id, 'check_b');
  });

  test(
    'composer builder canonical payload round trips without losing children',
    () {
      final module =
          ComposerModuleDraft.manual()
            ..moduleCode = 'ROUND-TRIP'
            ..title = 'Round trip module'
            ..fields = [
              ComposerFieldDraft(
                key: 'reading',
                label: 'Reading',
                type: ComposerFieldType.numericWithUnit,
                isRequired: true,
                order: 1,
                unit: 'bar',
              ),
            ]
            ..checklistItems = [
              ComposerChecklistItemDraft(
                id: 'check-reading',
                title: 'Check reading captured',
                isRequired: true,
                order: 1,
                linkedFieldKey: 'reading',
              ),
            ];
      final source = TemplateComposerDraft(
        title: 'Round trip template',
        assetType: AssetType.base,
        modules: [module],
        closureReviewConfirmed: true,
      );

      final output = ModuleComposerJsonBuilder.build(source);
      final restored = TemplateComposerDraft.fromPayloads(
        jobTemplateSnapshotJson: output.jobTemplateSnapshotJson,
        moduleSnapshotsJson: output.moduleSnapshotsJson,
        fieldDefinitionsJson: output.fieldDefinitionsJson,
        checklistJson: output.checklistJson,
      );

      expect(restored.modules, hasLength(1));
      expect(restored.modules.single.moduleCode, 'ROUND-TRIP');
      expect(restored.modules.single.fields.single.key, 'reading');
      expect(restored.modules.single.checklistItems.single.id, 'check-reading');
    },
  );

  test('governed custom hierarchy identity survives composer round trip', () {
    const hierarchyReference = AssetHierarchyReference(
      assetClassId: 'annealing-car-class',
      assetClassCode: 'ANNEALING_CAR',
      assetClassName: 'Annealing car',
      nodeId: 'car-body',
      nodeVersion: 3,
      nodeName: 'Car body',
      hierarchyPath: ['Car body'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'mechanical',
      accountableRoleKeys: ['seniorMechanical'],
    );
    final module =
        ComposerModuleDraft.manual(assetType: AssetType.governedCustom)
          ..moduleCode = 'CAR-01'
          ..title = 'Inspect car body'
          ..fields = [
            ComposerFieldDraft(
              key: 'condition',
              label: 'Condition',
              type: ComposerFieldType.text,
              isRequired: true,
              order: 1,
            ),
          ];
    final source = TemplateComposerDraft(
      title: 'Annealing car PM',
      assetType: AssetType.governedCustom,
      assetHierarchyRefJson: hierarchyReference.encode(),
      modules: [module],
    );

    expect(ModuleComposerValidator.validate(source).canSave, isTrue);
    final output = ModuleComposerJsonBuilder.build(source);
    final snapshot = jsonDecode(output.jobTemplateSnapshotJson) as Map;
    expect(snapshot['assetHierarchyRefJson'], hierarchyReference.encode());

    final restored = TemplateComposerDraft.fromPayloads(
      jobTemplateSnapshotJson: output.jobTemplateSnapshotJson,
      moduleSnapshotsJson: output.moduleSnapshotsJson,
      fieldDefinitionsJson: output.fieldDefinitionsJson,
      checklistJson: output.checklistJson,
    );
    expect(restored.assetType, AssetType.governedCustom);
    expect(
      restored.assetHierarchyReference?.assetClassId,
      'annealing-car-class',
    );
    expect(restored.assetHierarchyReference?.nodeId, 'car-body');
  });

  test(
    'governed custom composer draft without hierarchy identity is blocked',
    () {
      final result = ModuleComposerValidator.validate(
        TemplateComposerDraft(
          title: 'Unscoped custom PM',
          assetType: AssetType.governedCustom,
          modules: [ComposerModuleDraft.manual()],
        ),
      );

      expect(
        result.errors,
        contains(
          'Select a governed asset class and hierarchy definition for this custom template.',
        ),
      );
    },
  );
}
