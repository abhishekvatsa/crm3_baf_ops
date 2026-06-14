import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[320, 360, 412, 600]) {
    testWidgets('field and checklist cards remain usable at ${width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      try {
        final field = ComposerFieldDraft(
          key: 'leak_tight_shutoff_confirmed',
          label:
              'Confirm leak-tight shutoff condition before hydrogen admission',
          type: ComposerFieldType.yesNo,
          isRequired: true,
          order: 1,
          unit: 'confirmed',
        )..evidenceRole = ComposerEvidenceRole.leakTightShutoffConfirmation;
        final checklist = ComposerChecklistItemDraft(
          id: 'gas-safety-check-1',
          title:
              'Verify the isolation evidence and record the responsible operator',
          description:
              'Long safety-critical checklist guidance must remain readable on portrait devices.',
          isRequired: true,
          order: 1,
          linkedFieldKey: field.key,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1400),
                textScaler: const TextScaler.linear(1.35),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ComposerFieldCard(
                        key: ValueKey<String>(
                          'composer-field-card-${field.key}',
                        ),
                        field: field,
                        onRequiredChanged: (_) {},
                        onEdit: () {},
                        onDuplicate: () {},
                        onMoveUp: null,
                        onMoveDown: () {},
                        onDelete: () {},
                      ),
                      ComposerChecklistCard(
                        key: ValueKey<String>(
                          'composer-checklist-card-${checklist.id}',
                        ),
                        item: checklist,
                        onEdit: () {},
                        onDuplicate: () {},
                        onMoveUp: null,
                        onMoveDown: () {},
                        onDelete: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(ValueKey<String>('composer-field-card-${field.key}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('composer-field-edit-${field.key}')),
          findsOneWidget,
        );
        for (final action in <String>[
          'move-up',
          'move-down',
          'edit',
          'duplicate',
          'delete',
        ]) {
          expect(
            find.byKey(ValueKey<String>('composer-field-$action-${field.key}')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              ValueKey<String>('composer-checklist-$action-${checklist.id}'),
            ),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(
            ValueKey<String>('composer-checklist-edit-${checklist.id}'),
          ),
          findsOneWidget,
        );
        expect(find.text(field.label), findsOneWidget);
        expect(find.text(checklist.title), findsOneWidget);
        expect(tester.getSize(find.text(field.label)).width, greaterThan(140));
        expect(
          tester.getSize(find.text(checklist.title)).width,
          greaterThan(140),
        );
        expect(find.bySemanticsLabel('Delete ${field.label}'), findsWidgets);
        expect(
          find.bySemanticsLabel('Delete ${checklist.title}'),
          findsWidgets,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('field editor applies suggested semantic role and key', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final field = ComposerFieldDraft(
      key: 'field_6',
      label: 'Operator confirmation',
      type: ComposerFieldType.yesNo,
      isRequired: true,
      order: 1,
    );
    ComposerFieldDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await showDialog<ComposerFieldDraft>(
                        context: context,
                        builder: (_) => ComposerFieldEditorDialog(field: field),
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
    await tester.enterText(
      find.byKey(const Key('composer-field-label-input')),
      'Leak-tight shutoff confirmation',
    );
    await tester.pump();

    expect(
      find.text('Suggested key: $kLeakTightShutoffEvidenceFieldKey'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('composer-field-use-suggested-role')),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('composer-field-use-suggested-key')),
    );
    await tester.tap(find.byKey(const Key('composer-field-use-suggested-key')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-field-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.key, kLeakTightShutoffEvidenceFieldKey);
    expect(
      result!.evidenceRole,
      ComposerEvidenceRole.leakTightShutoffConfirmation,
    );
  });

  testWidgets('field editor preserves an unknown future evidence role', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final field = ComposerFieldDraft(
      key: 'future_evidence',
      label: 'Future governed evidence',
      type: ComposerFieldType.text,
      isRequired: false,
      order: 1,
      meta: <String, dynamic>{
        kComposerEvidenceRoleMetaKey: 'future_server_defined_role',
        'preserveMe': true,
      },
    );
    ComposerFieldDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await showDialog<ComposerFieldDraft>(
                        context: context,
                        builder: (_) => ComposerFieldEditorDialog(field: field),
                      );
                    },
                    child: const Text('Open future editor'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open future editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composer-field-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.meta[kComposerEvidenceRoleMetaKey],
      'future_server_defined_role',
    );
    expect(result!.meta['preserveMe'], isTrue);
  });
}
