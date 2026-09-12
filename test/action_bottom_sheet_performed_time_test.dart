import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/widgets/action_bottom_sheet.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/widgets/action_performed_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

final _start = DateTime.utc(2026, 9, 1);
final _older = DateTime.utc(2026, 9, 10, 4, 45);
final _newer = DateTime.utc(2026, 9, 12, 6, 5);
final _captured = <String, dynamic>{};

void main() {
  for (final component in ['burner', 'uv']) {
    for (final instant in {'older': _older, 'newer': _newer}.entries) {
      testWidgets(
        '$component ${instant.key} physical time survives form edits and wire encoding',
        (tester) async {
          ComponentAction? result;
          await _open(
            tester,
            component: component,
            receive: (value) => result = value,
          );
          await _chooseTargetAndReplacement(tester, component);
          expect(
            _saveButton(tester).onPressed,
            isNull,
            reason: 'Entry time must never silently become physical work time.',
          );
          await _pick(tester, instant.value);
          final notes = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Issue / observation',
          );
          await tester.ensureVisible(notes);
          await tester.enterText(
            notes,
            'Work recorded later; installation time confirmed.',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          // Editing other evidence must not reset the time to DateTime.now().
          expect(
            tester
                .widget<ActionPerformedTimeField>(
                  find.byType(ActionPerformedTimeField),
                )
                .value,
            instant.value.toLocal(),
          );
          await _tap(tester, find.text('Save Action'));
          final action = result!;
          expect(action.createdAt.toUtc(), instant.value);
          expect(action.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
          final wire = action.toMap();
          expect(wire['createdAt'], instant.value.toIso8601String());
          final execution = JobExecution()..actions = [action];
          expect((jsonDecode(execution.actionsJson) as List).single, wire);
          // Only the random action identity is replaced for reproducible fixtures.
          // Timestamp and all physical evidence come from the actual sheet.
          _captured['$component-${instant.key}'] = {
            ...wire,
            'id': 'ui-$component-${instant.key}',
          };
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'cancelled time selection and clearing never create a guessed time',
    (tester) async {
      await _open(tester, receive: (_) {});
      await _chooseTargetAndReplacement(tester, 'uv');
      await _tap(tester, find.byKey(const ValueKey('action-performed-time')));
      await _tap(tester, find.text('Cancel').last);
      expect(_saveButton(tester).onPressed, isNull);
      await _pick(tester, _older);
      expect(_saveButton(tester).onPressed, isNotNull);
      await _tap(
        tester,
        find.byKey(const ValueKey('clear-action-performed-time')),
      );
      expect(_saveButton(tester).onPressed, isNull);
    },
  );

  for (final invalid in {
    'before work began': _start.subtract(const Duration(minutes: 1)),
    'after work ended': _newer.add(const Duration(minutes: 1)),
    'future': DateTime.now().add(const Duration(days: 2)),
  }.entries) {
    testWidgets(
      '${invalid.key} supplied time is retained visibly but cannot save',
      (tester) async {
        await _open(
          tester,
          initial: invalid.value,
          end: _newer,
          receive: (_) {},
        );
        await _chooseTargetAndReplacement(tester, 'uv');
        expect(_saveButton(tester).onPressed, isNull);
        expect(
          tester
              .widget<ActionPerformedTimeField>(
                find.byType(ActionPerformedTimeField),
              )
              .value,
          invalid.value,
        );
        expect(find.byType(ActionBottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a supplied precise work time survives unrelated edits exactly', (
    tester,
  ) async {
    final original = _older.add(
      const Duration(seconds: 12, microseconds: 345678),
    );
    ComponentAction? result;
    await _open(tester, initial: original, receive: (value) => result = value);
    await _chooseTargetAndReplacement(tester, 'uv');
    await _tap(tester, find.text('Save Action'));
    expect(result!.createdAt, original);
  });

  test(
    'future or contradictory job bounds fail closed; real endpoints are inclusive',
    () {
      final now = DateTime.utc(2026, 9, 13);
      expect(
        componentActionTimeError(
          performedAt: _older,
          workStartedAt: now.add(const Duration(seconds: 1)),
          now: now,
        ),
        isNotNull,
      );
      expect(
        componentActionTimeError(
          performedAt: _older,
          workStartedAt: _start,
          workCompletedAt: _start.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isNotNull,
      );
      for (final at in [_start, _newer]) {
        expect(
          componentActionTimeError(
            performedAt: at,
            workStartedAt: _start,
            workCompletedAt: _newer,
            now: now,
          ),
          isNull,
        );
      }
    },
  );

  test('actual picker specimens match backend fixture', () {
    final file = File(
      'functions/test/fixtures/planned_component_action_performed_times.json',
    );
    if (Platform.environment['UPDATE_ACTION_TIME_FIXTURE'] == 'true') {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(_captured)}\n',
      );
    }
    expect(_captured.length, 4);
    expect(jsonDecode(file.readAsStringSync()), _captured);
  });
}

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Save Action'),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  String component = 'uv',
  DateTime? initial,
  DateTime? end,
  required void Function(ComponentAction?) receive,
}) async {
  tester.view.physicalSize = const Size(1000, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assetHierarchyRepositoryProvider.overrideWithValue(
          _Hierarchy(component),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => receive(
                await showModalBottomSheet<ComponentAction>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ActionBottomSheet(
                    target: const GovernedActionContext(
                      assetTypeKey: 'furnace',
                      assetNumber: 7,
                    ),
                    workStartedAt: _start,
                    workCompletedAt: end,
                    performedAt: initial,
                    performedBy: 'Maintainer',
                    workDiscipline: component == 'uv'
                        ? 'instrumentation'
                        : 'mechanical',
                  ),
                ),
              ),
              child: const Text('Open action'),
            ),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Open action'));
}

Future<void> _chooseTargetAndReplacement(
  WidgetTester tester,
  String component,
) async {
  await _tap(tester, find.text('Choose from asset hierarchy'));
  await _tap(
    tester,
    find.byTooltip('Use ${component == 'uv' ? 'UV detector' : 'Burner block'}'),
  );
  await _tap(tester, find.byType(DropdownButtonFormField<ActionType>));
  await _tap(tester, find.text('Replacement').last);
  await _tap(tester, find.byType(DropdownButtonFormField<ReplacementType>));
  await _tap(tester, find.text('New part').last);
  await _tap(tester, find.byType(DropdownButtonFormField<int>));
  await _tap(tester, find.text('Burner 3').last);
  if (component == 'burner') {
    await _tap(
      tester,
      find.byType(DropdownButtonFormField<BurnerBlockSupplyMode>),
    );
    await _tap(tester, find.text('SAIL-made by RED').last);
  }
}

Future<void> _pick(WidgetTester tester, DateTime instant) async {
  final local = instant.toLocal();
  await _tap(tester, find.byKey(const ValueKey('action-performed-time')));
  final dateContext = tester.element(find.byType(DatePickerDialog));
  await _tap(
    tester,
    find.byTooltip(
      MaterialLocalizations.of(dateContext).inputDateModeButtonLabel,
    ),
  );
  final input = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(input, DateFormat.yMd('en_US').format(local));
  await _tap(tester, find.text('OK').last);
  final timeContext = tester.element(find.byType(TimePickerDialog));
  await _tap(
    tester,
    find.byTooltip(
      MaterialLocalizations.of(timeContext).inputTimeModeButtonLabel,
    ),
  );
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), '${local.hour}');
  await tester.enterText(fields.at(1), '${local.minute}');
  await _tap(tester, find.text('OK').last);
}

class _Hierarchy extends Fake implements AssetHierarchyRepository {
  _Hierarchy(this.component);
  final String component;
  @override
  Stream<List<AssetClassRecord>> watchAssetClasses() => Stream.value([
    AssetClassRecord(
      id: 'class-furnace',
      code: 'FURNACE',
      name: 'Furnace',
      majorArea: 'BAF',
      legacyAssetTypeKey: 'furnace',
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: _start,
      createdByUid: 'admin',
      updatedAt: _start,
      updatedByUid: 'admin',
      lastMutationId: 'class-mutation',
    ),
  ]);
  @override
  Stream<List<AssetInstanceRecord>> watchAssetInstances(String assetClassId) =>
      Stream.value([
        AssetInstanceRecord(
          id: 'furnace-7',
          assetClassId: 'class-furnace',
          assetClassCode: 'FURNACE',
          assetClassName: 'Furnace',
          assetNumber: 7,
          name: 'Furnace 7',
          serviceState: AssetServiceState.inService,
          ownershipStatus: AssetOwnershipStatus.confirmed,
          status: AssetHierarchyStatus.active,
          activeComponentCount: 0,
          version: 1,
          createdAt: _start,
          updatedAt: _start,
          lastMutationId: 'asset-mutation',
        ),
      ]);
  @override
  Stream<List<AssetHierarchyNode>> watchNodes(String assetClassId) =>
      Stream.value([
        AssetHierarchyNode(
          id: 'node-$component',
          assetClassId: 'class-furnace',
          nodeType: AssetHierarchyNodeType.component,
          name: component == 'uv' ? 'UV detector' : 'Burner block',
          contactArrangement: ElectricalContactArrangement.notApplicable,
          ownershipStatus: AssetOwnershipStatus.confirmed,
          sortOrder: 1,
          ancestorNodeIds: const [],
          hierarchyPath: [
            'Furnace',
            component == 'uv' ? 'UV detector' : 'Burner block',
          ],
          activeChildCount: 0,
          status: AssetHierarchyStatus.active,
          version: 1,
          createdAt: _start,
          createdByUid: 'admin',
          updatedAt: _start,
          updatedByUid: 'admin',
          lastMutationId: 'node-mutation',
        ),
      ]);
}
