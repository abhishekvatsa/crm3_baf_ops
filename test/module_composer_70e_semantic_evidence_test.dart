import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_json_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('70E structured evidence semantics', () {
    test('suggests canonical role and technical key from author label', () {
      const label = 'Leak-tight shutoff confirmation';

      expect(
        suggestComposerEvidenceRole(label),
        ComposerEvidenceRole.leakTightShutoffConfirmation,
      );
      expect(
        suggestedComposerFieldKey(
          label: label,
          evidenceRole: ComposerEvidenceRole.leakTightShutoffConfirmation,
        ),
        kLeakTightShutoffEvidenceFieldKey,
      );
    });

    test(
      'structured role satisfies gas-risk validation with a generic key',
      () {
        final field = ComposerFieldDraft(
          key: 'field_6',
          label: 'Gas train isolation evidence',
          type: ComposerFieldType.yesNo,
          isRequired: true,
          order: 1,
        )..evidenceRole = ComposerEvidenceRole.leakTightShutoffConfirmation;
        final result = ModuleComposerValidator.validate(
          _draftWithGasField(field),
        );

        expect(
          result.warnings.where((message) => message.contains('Gas-risk')),
          isEmpty,
        );
      },
    );

    test('legacy semantic key remains accepted for old snapshots', () {
      final field = ComposerFieldDraft(
        key: 'leak_tightness_check',
        label: 'Existing legacy evidence',
        type: ComposerFieldType.yesNo,
        isRequired: true,
        order: 1,
      );
      final result = ModuleComposerValidator.validate(
        _draftWithGasField(field),
      );

      expect(
        result.warnings.where((message) => message.contains('Gas-risk')),
        isEmpty,
      );
    });

    test('missing gas evidence warning teaches role and canonical key', () {
      final field = ComposerFieldDraft(
        key: 'field_6',
        label: 'Operator confirmation',
        type: ComposerFieldType.yesNo,
        isRequired: true,
        order: 1,
      );
      final result = ModuleComposerValidator.validate(
        _draftWithGasField(field),
      );
      final warning = result.warnings.singleWhere(
        (message) => message.contains('Gas-risk'),
      );

      expect(warning, contains('Evidence role'));
      expect(
        warning,
        contains(
          composerEvidenceRoleLabel(
            ComposerEvidenceRole.leakTightShutoffConfirmation,
          ),
        ),
      );
      expect(warning, contains(kLeakTightShutoffEvidenceFieldKey));
    });

    test('evidence role round trips through existing field metadata JSON', () {
      final field = ComposerFieldDraft(
        key: 'field_6',
        label: 'Leak-tight shutoff confirmation',
        type: ComposerFieldType.yesNo,
        isRequired: true,
        order: 1,
      )..evidenceRole = ComposerEvidenceRole.leakTightShutoffConfirmation;
      final source = _draftWithGasField(field);
      final output = ModuleComposerJsonBuilder.build(source);
      final fieldPayload =
          (jsonDecode(output.fieldDefinitionsJson) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .single;
      final meta = Map<String, dynamic>.from(fieldPayload['meta'] as Map);

      expect(
        meta[kComposerEvidenceRoleMetaKey],
        ComposerEvidenceRole.leakTightShutoffConfirmation.name,
      );

      final restored = TemplateComposerDraft.fromPayloads(
        jobTemplateSnapshotJson: output.jobTemplateSnapshotJson,
        moduleSnapshotsJson: output.moduleSnapshotsJson,
        fieldDefinitionsJson: output.fieldDefinitionsJson,
        checklistJson: output.checklistJson,
      );

      expect(
        restored.modules.single.fields.single.evidenceRole,
        ComposerEvidenceRole.leakTightShutoffConfirmation,
      );
    });
  });
}

TemplateComposerDraft _draftWithGasField(ComposerFieldDraft field) {
  final module =
      ComposerModuleDraft.manual()
        ..moduleCode = 'GAS-ROLE-01'
        ..title = 'Gas safety evidence'
        ..safetyClasses = <String>['gasRisk']
        ..fields = <ComposerFieldDraft>[field];
  return TemplateComposerDraft(
    title: '70E semantic evidence test',
    assetType: AssetType.furnace,
    modules: <ComposerModuleDraft>[module],
  );
}
