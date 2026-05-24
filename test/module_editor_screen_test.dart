import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'focused editor saves edited clone without mutating source draft',
    (tester) async {
      final source = _module();
      ComposerModuleDraft? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        result = await Navigator.of(
                          context,
                        ).push<ComposerModuleDraft>(
                          MaterialPageRoute(
                            builder: (_) => ModuleEditorScreen(module: source),
                          ),
                        );
                      },
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('module-editor-title-field'));
      expect(titleField, findsOneWidget);

      await tester.enterText(titleField, 'Edited clamp verification');
      await tester.pump();

      expect(source.title, 'PSL13 clamp verification');

      await tester.tap(find.text('Save Module'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.title, 'Edited clamp verification');
      expect(source.title, 'PSL13 clamp verification');
    },
  );

  testWidgets(
    'focused editor discard returns null and preserves source draft',
    (tester) async {
      final source = _module();
      Object? result = Object();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        result = await Navigator.of(
                          context,
                        ).push<ComposerModuleDraft>(
                          MaterialPageRoute(
                            builder: (_) => ModuleEditorScreen(module: source),
                          ),
                        );
                      },
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('module-editor-title-field'));
      expect(titleField, findsOneWidget);

      await tester.enterText(titleField, 'Discarded change');
      await tester.pump();

      expect(source.title, 'PSL13 clamp verification');

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(source.title, 'PSL13 clamp verification');
    },
  );

  testWidgets(
    'field edit dialog owns controllers until route is fully removed',
    (tester) async {
      final source = _module();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push<ComposerModuleDraft>(
                          MaterialPageRoute(
                            builder: (_) => ModuleEditorScreen(module: source),
                          ),
                        );
                      },
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Pressure OK'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Pressure OK'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('module-editor-field-menu-pressure_ok')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit field'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'pressure_ok');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

ComposerModuleDraft _module() {
  return ComposerModuleDraft(
    localId: 'local-psl13-clamp',
    moduleCode: 'PSL13-CLAMP',
    title: 'PSL13 clamp verification',
    description: 'Verify hydraulic clamp readiness.',
    assetType: AssetType.base,
    discipline: JobModuleDiscipline.shared,
    ownerDisciplines: ['mechanical', 'instrumentation'],
    primaryOwner: 'mechanical',
    requiresJointReview: true,
    useMode: JobModuleUseMode.scheduledPM,
    functionalSection: 'Hydraulic clamp',
    componentGroup: 'PSL13',
    subsystem: 'Clamp circuit',
    safetyClasses: ['hydraulic', 'interlock'],
    targetRefs: ['psl13'],
    deviceTagRefs: ['PSL13'],
    procedureRefs: ['SOP-CLAMP'],
    partRefs: ['clamp'],
    operationalStatePreconditions: ['Line stopped'],
    requiredForClosure: true,
    frequency: MaintenanceFrequency.everyCharge,
    fields: [
      ComposerFieldDraft(
        key: 'pressure_ok',
        label: 'Pressure OK',
        type: ComposerFieldType.yesNo,
        isRequired: true,
        order: 1,
        instructionText: 'Confirm pressure switch indication.',
        validation: {
          'expected': true,
          'nested': {'changed': false},
        },
        meta: {'source': 'test'},
        isSafetyCriticalPreset: true,
      ),
    ],
    checklistItems: [
      ComposerChecklistItemDraft(
        id: 'PSL13-CLAMP-item-1',
        title: 'Verify pressure switch',
        description: 'Confirm PSL13 low-pressure switch before closure.',
        isRequired: true,
        order: 1,
        linkedFieldKey: 'pressure_ok',
        safetyClasses: ['hydraulic'],
        metadata: {'source': 'test'},
      ),
    ],
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    authoringNotes: 'Test fixture.',
    metadata: {
      'source': 'test',
      'nested': {'changed': false},
    },
  );
}
