import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/complete_job_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/create_template_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_history_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';

AppUser _actor([String uid = 'admin']) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

JobExecution _execution() => JobExecution()
  ..id = 7
  ..firestoreId = 'execution-7'
  ..templateFirestoreId = 'template-7'
  ..templateName = 'Evidence template'
  ..assetType = AssetType.base
  ..assetNumber = 7
  ..createdAt = DateTime.utc(2026, 9, 20)
  ..updatedAt = DateTime.utc(2026, 9, 20)
  ..responsesJson = FieldResponse.encode([
    FieldResponse(
      key: 'text',
      fieldLabel: 'Condition',
      fieldType: FieldType.text,
      value: 'Original condition',
    ),
    FieldResponse(
      key: 'long',
      fieldLabel: 'Inspection notes',
      fieldType: FieldType.longText,
      value: 'Original detailed notes',
    ),
    FieldResponse(
      key: 'number',
      fieldLabel: 'Pressure',
      fieldType: FieldType.number,
      value: 12.5,
    ),
  ]);

JobTemplate _template() => JobTemplate()
  ..firestoreId = 'template-7'
  ..jobName = 'Evidence template'
  ..applicableAssetType = AssetType.base
  ..setFields([
    TemplateField(
      key: 'text',
      label: 'Condition',
      type: FieldType.text,
      isRequired: true,
    ),
    TemplateField(
      key: 'long',
      label: 'Inspection notes',
      type: FieldType.longText,
      isRequired: true,
    ),
    TemplateField(
      key: 'number',
      label: 'Pressure',
      type: FieldType.number,
      isRequired: true,
    ),
  ]);

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

class _Planned extends Fake implements PlannedMaintenanceRepository {
  _Planned(this.template, this.executions);
  final JobTemplate template;
  final List<JobExecution> executions;
  int saves = 0;
  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String id) async => template;
  @override
  Future<List<JobExecution>> getExecutionsForTemplate(String id) async =>
      executions;
  @override
  Future<void> saveTemplate(JobTemplate value, {required AppUser actor}) async {
    saves++;
  }
}

Finder _input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
void _large(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'completion shows all saved text and number entries and preserves validation',
    (tester) async {
      _large(tester);
      final execution = _execution();
      final original = execution.responsesJson;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_actor()),
            ),
            plannedRepositoryProvider.overrideWithValue(
              _Planned(_template(), []),
            ),
            jobModulesProvider.overrideWith(
              (ref, query) => Stream.value(<JobModuleInstance>[]),
            ),
          ],
          child: MaterialApp(home: CompleteJobScreen(execution: execution)),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in {
        'Condition *': 'Original condition',
        'Inspection notes *': 'Original detailed notes',
        'Pressure *': '12.5',
      }.entries) {
        await tester.scrollUntilVisible(
          _input(entry.key),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<TextField>(_input(entry.key)).controller!.text,
          entry.value,
        );
      }
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      await tester.enterText(_input('Pressure *'), 'not a number');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a valid number'), findsOneWidget);
      await tester.enterText(_input('Pressure *'), '12.5');
      await tester.enterText(_input('Condition *'), '');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      expect(execution.responsesJson, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history retains original key and value after a template field is removed',
    (tester) async {
      _large(tester);
      final execution = _execution()..isCompleted = true;
      final original = execution.responsesJson;
      final template = _template()
        ..setFields([
          TemplateField(
            key: 'text',
            label: 'Current condition label',
            type: FieldType.text,
          ),
        ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plannedRepositoryProvider.overrideWithValue(
              _Planned(template, [execution]),
            ),
          ],
          child: MaterialApp(home: JobHistoryScreen(template: template)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Responses'));
      await tester.tap(find.text('View Responses'));
      await tester.pumpAndSettle();
      final sheet = find.byType(DraggableScrollableSheet);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('SAVED FIELDS FROM AN EARLIER TEMPLATE'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Inspection notes (long)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Original detailed notes'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Pressure (number)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('12.5')),
        findsOneWidget,
      );
      expect(execution.responsesJson, original);
      expect(tester.takeException(), isNull);
    },
  );

  for (final interruption in ['refresh', 'account switch', 'error']) {
    testWidgets(
      'template form rejects $interruption and retains entered draft',
      (tester) async {
        _large(tester);
        final accounts = StreamController<AppUser?>.broadcast();
        final repository = _Planned(_template(), []);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => accounts.stream),
              firebaseAuthProvider.overrideWithValue(_Auth()),
              assetClassesProvider.overrideWith(
                (ref) => Stream.value(<AssetClassRecord>[]),
              ),
              plannedRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(home: CreateTemplateScreen()),
          ),
        );
        accounts.add(_actor());
        await tester.pumpAndSettle();
        await tester.enterText(_input('Job name'), 'Retained template draft');
        await tester.tap(find.text('MECHANICAL'));
        await tester.pump();
        final button = find.widgetWithText(FilledButton, 'Create Template');
        final submit = tester.widget<FilledButton>(button).onPressed!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CreateTemplateScreen)),
        );
        if (interruption == 'refresh') {
          container.invalidate(currentAppUserProvider);
        } else if (interruption == 'error') {
          accounts.addError(StateError('Account unavailable'));
        } else {
          accounts.add(_actor('other-admin'));
        }
        await tester.pump();
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        submit();
        await tester.pumpAndSettle();
        expect(repository.saves, 0);
        expect(
          tester.widget<TextField>(_input('Job name')).controller!.text,
          'Retained template draft',
        );
        accounts.add(_actor());
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await accounts.close();
      },
    );
  }
}
