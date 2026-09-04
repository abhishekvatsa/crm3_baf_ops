import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/frequent_issue_definition.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/frequent_issue_provider.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:crm3_baf_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lockout notes are optional without relaxing ordinary issues', (
    tester,
  ) async {
    await _pumpForm(tester);
    await _tap(tester, find.text('Not suspected'));
    await _chooseClass(tester, 'Furnace');
    await _scrollTo(tester, find.text('Burner lockout'));
    await _tap(tester, find.text('Burner lockout'));
    await _scrollTo(tester, find.text('B2'));
    await _tap(tester, find.text('B2'));
    await _tap(tester, find.text('B5'));
    final notes = find.ancestor(
      of: find.text('Additional notes (optional)'),
      matching: find.byType(TextFormField),
    );
    await _scrollTo(tester, notes);
    expect(tester.state<FormFieldState<String>>(notes).validate(), isTrue);
    await tester.enterText(notes, '  ');
    expect(tester.state<FormFieldState<String>>(notes).validate(), isTrue);
    await tester.enterText(notes, 'x' * 2001);
    expect(tester.state<FormFieldState<String>>(notes).validate(), isFalse);
    await tester.enterText(notes, 'Observation retained');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Standard issue'), backwards: true);
    await _tap(tester, find.text('Standard issue'));
    final description = find.ancestor(
      of: find.text('Fault description'),
      matching: find.byType(TextFormField),
    );
    await _scrollTo(tester, description);
    expect(
      tester.widget<TextFormField>(description).controller!.text,
      'Observation retained',
    );
    await tester.enterText(description, '');
    expect(
      tester.state<FormFieldState<String>>(description).validate(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged asset selection retains the frequent-issue choice', (
    tester,
  ) async {
    await _pumpForm(tester);
    await _tap(tester, find.text('Not suspected'));
    await _chooseClass(tester, 'Base');
    await _scrollTo(tester, find.byTooltip('Choose issue'));
    await _tap(tester, find.byTooltip('Choose issue'));
    await _tap(tester, find.text('Hydraulic clamp leakage'));
    final classField = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Asset class',
    );
    await _scrollTo(tester, classField, backwards: true);
    await _chooseClass(tester, 'Base');
    await _scrollTo(tester, find.text('Frequent issue'));
    expect(find.text('Hydraulic clamp leakage'), findsOneWidget);
    await _tap(tester, find.text('Submit Issue'));
    expect(find.text('Hydraulic clamp leakage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'submission validates a quality note even when scrolled offscreen',
    (tester) async {
      await _pumpForm(tester);
      await _enterQuality(tester);
      await tester.enterText(_reason, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Operational timing'));
      await _tap(tester, find.text('Submit Issue'));
      expect(find.text('Describe the suspected effect'), findsOneWidget);
      expect(_assessment(tester).selected, {IssueQualityAssessment.suspected});
      expect(
        tester.state<FormFieldState<String>>(_classification).value,
        'qc-1',
      );
    },
  );

  for (final predictive in [false, true]) {
    testWidgets(
      'app shell and form cooperate on Back (predictive=$predictive)',
      (tester) async {
        await _pumpForm(tester, appShell: true);
        await _enterQuality(tester);
        await tester.showKeyboard(_reason);
        Future<void> back() async {
          if (predictive) {
            await _sendBackGesture(tester, 'startBackGesture', {
              'touchOffset': <double>[5, 300],
              'progress': 0.0,
              'swipeEdge': 0,
            });
            await _sendBackGesture(tester, 'commitBackGesture');
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
        }

        await back();
        expect(find.byType(MaintenanceForm), findsOneWidget);
        expect(find.text('Discard this issue?'), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        await back();
        expect(find.text('Discard this issue?'), findsOneWidget);
        await _tap(tester, find.text('Keep editing'));
        expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'quality starts unselected but tapping the chosen answer keeps it',
    (tester) async {
      await _pumpForm(tester);
      expect(_assessment(tester).selected, isEmpty);
      await _tap(tester, find.text('Suspected'));
      await _tap(tester, find.text('Suspected'));
      expect(_assessment(tester).selected, {IssueQualityAssessment.suspected});
      expect(find.text('Suspected abnormality classification'), findsOneWidget);
    },
  );

  testWidgets('choosing the asset later retains an applicable quality reason', (
    tester,
  ) async {
    await _pumpForm(tester);
    await _enterQuality(tester);
    await _chooseClass(tester, 'Base');
    await _scrollTo(tester, find.text('Quality impact'), backwards: true);
    expect(_assessment(tester).selected, {IssueQualityAssessment.suspected});
    expect(tester.state<FormFieldState<String>>(_classification).value, 'qc-1');
    expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching the answer does not erase an unfinished quality note',
    (tester) async {
      await _pumpForm(tester);
      await _enterQuality(tester);
      await _scrollTo(tester, find.text('Quality impact'), backwards: true);
      await _tap(tester, find.text('Not suspected'));
      await _tap(tester, find.text('Suspected'));
      expect(
        tester.state<FormFieldState<String>>(_classification).value,
        'qc-1',
      );
      expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
    },
  );

  testWidgets(
    'classification refresh retains the draft and restores the field',
    (tester) async {
      final types = StreamController<List<AbnormalityType>>();
      addTearDown(types.close);
      types.add([_qualityType()]);
      await _pumpForm(tester, types: types.stream);
      await _enterQuality(tester);
      types.add([]);
      await tester.pumpAndSettle();
      expect(_assessment(tester).selected, {IssueQualityAssessment.suspected});
      types.add([_qualityType()]);
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(_classification).value,
        'qc-1',
      );
      expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inapplicable classification is explained without erasing the draft',
    (tester) async {
      await _pumpForm(tester);
      await _enterQuality(tester);
      await _chooseClass(tester, 'Furnace');
      await _scrollTo(tester, find.text('Quality impact'), backwards: true);
      expect(
        find.textContaining('Choose a classification for this asset'),
        findsOneWidget,
      );
      expect(
        tester.state<FormFieldState<String>>(_classification).validate(),
        isFalse,
      );
      expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
      await _chooseClass(tester, 'Base');
      await _scrollTo(tester, find.text('Quality impact'), backwards: true);
      expect(
        tester.state<FormFieldState<String>>(_classification).value,
        'qc-1',
      );
    },
  );

  testWidgets('failed submission and scrolling do not reset quality evidence', (
    tester,
  ) async {
    await _pumpForm(tester);
    await _enterQuality(tester);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Operational timing'),
      400,
      scrollable: scrollable,
    );
    await _tap(tester, find.text('Submit Issue'));
    await _scrollTo(tester, find.text('Quality impact'), backwards: true);
    expect(_assessment(tester).selected, {IssueQualityAssessment.suspected});
    expect(tester.state<FormFieldState<String>>(_classification).value, 'qc-1');
    expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
    expect(find.byType(MaintenanceForm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final keyboardHeight in [0.0, 280.0]) {
    testWidgets(
      'Back dismisses editor before discard confirmation ($keyboardHeight)',
      (tester) async {
        await _pumpForm(tester);
        await _enterQuality(tester);
        await tester.showKeyboard(_reason);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MaintenanceForm), findsOneWidget);
        expect(find.text('Discard this issue?'), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Discard this issue?'), findsOneWidget);
        await _tap(tester, find.text('Keep editing'));
        expect(find.byType(MaintenanceForm), findsOneWidget);
        expect(tester.widget<TextFormField>(_reason).controller!.text, _note);
      },
    );
  }

  testWidgets('app bar Back also protects keyboard and unfinished entries', (
    tester,
  ) async {
    await _pumpForm(tester);
    await _enterQuality(tester);
    await tester.showKeyboard(_reason);
    await _tap(tester, find.byType(BackButton));
    expect(find.byType(MaintenanceForm), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('Discard this issue?'), findsOneWidget);
    await _tap(tester, find.text('Discard issue'));
    expect(find.byType(MaintenanceForm), findsNothing);
    expect(find.text('Issue list'), findsOneWidget);
  });
}

const _note = 'Coil colour needs checking after cooling.';

final _classification = find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == 'Suspected abnormality classification',
);
final _reason = find.ancestor(
  of: find.text('Suspected quality effect'),
  matching: find.byType(TextFormField),
);

SegmentedButton<IssueQualityAssessment> _assessment(WidgetTester tester) =>
    tester.widget(find.byType(SegmentedButton<IssueQualityAssessment>));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  bool backwards = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    backwards ? -350 : 350,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
}

Future<void> _enterQuality(WidgetTester tester) async {
  await _tap(tester, find.text('Suspected'));
  await _tap(tester, _classification);
  await _tap(tester, find.text('QC01 · Suspected coil colour').last);
  await tester.ensureVisible(_reason);
  await tester.enterText(_reason, _note);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _chooseClass(WidgetTester tester, String name) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Asset class',
  );
  await _scrollTo(tester, field);
  await _tap(tester, field);
  await _tap(tester, find.text(name).last);
}

Future<void> _pumpForm(
  WidgetTester tester, {
  Stream<List<AbnormalityType>>? types,
  bool appShell = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'draft-operator',
              name: 'Draft Operator',
              email: 'operator@example.com',
              roles: const [AppRole.operations],
              isApproved: true,
              createdAt: DateTime.utc(2026, 9, 1),
            ),
          ),
        ),
        activeAbnormalityTypesProvider.overrideWith(
          (ref) => types ?? Stream.value([_qualityType()]),
        ),
        frequentIssueDefinitionsProvider.overrideWith(
          (ref) => Stream.value([_frequentIssue()]),
        ),
        assetClassesProvider.overrideWith(
          (ref) => Stream.value([
            _assetClass('base', 'Base'),
            _assetClass('furnace', 'Furnace'),
          ]),
        ),
        assetInstancesProvider.overrideWith((ref, classId) => Stream.value([])),
        innerCoverAssignmentsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child:
          appShell
              ? CrmBafApp(
                startupFailure: StartupFailure(
                  stage: 'firebase_initialize',
                  error: StateError('Local test shell'),
                  stackTrace: StackTrace.current,
                  occurredAt: DateTime.utc(2026, 9, 4),
                ),
              )
              : MaterialApp(
                theme: BafAppTheme.light,
                home: const Scaffold(body: Text('Issue list')),
              ),
    ),
  );
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute<void>(builder: (_) => const MaintenanceForm()));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

AbnormalityType _qualityType() =>
    AbnormalityType()
      ..firestoreId = 'qc-1'
      ..code = 'QC01'
      ..title = 'Suspected coil colour'
      ..category = AbnormalityCategory.process
      ..severity = AbnormalitySeverity.high
      ..applicableAssetTypes = [AssetType.base]
      ..isActive = true;

AssetClassRecord _assetClass(String id, String name) => AssetClassRecord(
  id: id,
  code: id.toUpperCase(),
  name: name,
  majorArea: 'BAF',
  legacyAssetTypeKey: id,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026, 9, 1),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026, 9, 1),
  updatedByUid: 'admin',
  lastMutationId: '$id-1',
);

FrequentIssueDefinition _frequentIssue() => FrequentIssueDefinition(
  id: 'clamp-leak',
  version: 1,
  status: FrequentIssueDefinitionStatus.active,
  code: 'CL01',
  title: 'Hydraulic clamp leakage',
  description: 'Clamp is leaking.',
  applicableAssetTypeKeys: const ['base'],
  applicableAssetClassIds: const [],
  applicableComponentNodeIds: const [],
  suggestedSeverityKey: 'normal',
  suggestedMaintenanceTypeKey: 'breakdown',
  defaultRouteKey: 'mechanical',
  requiredEvidenceFields: const [],
  aliases: const [],
  createdAt: DateTime.utc(2026, 9, 1),
  createdByUid: 'admin',
  createdByName: 'Admin',
  updatedAt: DateTime.utc(2026, 9, 1),
  updatedByUid: 'admin',
  updatedByName: 'Admin',
);

Future<void> _sendBackGesture(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (ByteData? _) {},
  );
}
