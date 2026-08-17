import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/resolve_form.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validAction({Map<String, dynamic>? additions}) =>
    <String, dynamic>{
      'asset': 'base-1',
      'component': 'hydraulic valve',
      'actionType': 'repair',
      'isAutoResolved': false,
      'createdAt': '2026-08-05T08:00:00.000Z',
      'severity': 'high',
      'version': 1,
      ...?additions,
    };

void main() {
  group('A-05 component-action persisted integrity', () {
    test('valid legacy actions canonicalize to payload schema version 1', () {
      final raw = jsonEncode([
        _validAction(
          additions: {
            'hierarchyPath': ['base-1', 'hydraulics'],
          },
        ),
      ]);

      final actions = ComponentAction.decode(
        raw,
        source: 'job execution execution-1',
      );
      expect(actions, hasLength(1));
      expect(actions.single.createdAt, DateTime.utc(2026, 8, 5, 8));
      expect(actions.single.extensions, isEmpty);

      final rewritten = jsonDecode(ComponentAction.encode(actions)) as List;
      expect((rewritten.single as Map)['schemaVersion'], 1);
    });

    test('malformed or incomplete saved actions fail closed', () {
      final malformed = <String>[
        '{not-json',
        '{}',
        '["action"]',
        jsonEncode([_validAction()..remove('asset')]),
        jsonEncode([
          _validAction(additions: {'actionType': 'weld'}),
        ]),
        jsonEncode([
          _validAction(additions: {'isAutoResolved': 0}),
        ]),
        jsonEncode([_validAction()..remove('createdAt')]),
        jsonEncode([
          _validAction(additions: {'createdAt': 'soon'}),
        ]),
        jsonEncode([
          _validAction(additions: {'severity': 'urgent'}),
        ]),
        jsonEncode([
          _validAction(additions: {'version': 0}),
        ]),
        jsonEncode([
          _validAction(
            additions: {
              'hierarchyPath': [3],
            },
          ),
        ]),
        jsonEncode([
          _validAction(additions: {'futureAuthority': true}),
        ]),
        jsonEncode([
          _validAction(additions: {'schemaVersion': 2}),
        ]),
      ];

      for (final raw in malformed) {
        expect(
          () => ComponentAction.decode(raw, source: 'maintenance/ticket-1'),
          throwsA(isA<PersistedDataFormatException>()),
          reason: raw,
        );
        final read = ComponentAction.tryDecode(
          raw,
          source: 'maintenance/ticket-1',
        );
        expect(read.isValid, isFalse, reason: raw);
        expect(read.entries, isEmpty, reason: raw);
      }
    });

    test('model read results never invent zero actions for corrupt JSON', () {
      final maintenance =
          MaintenanceRecord()
            ..firestoreId = 'ticket-1'
            ..actionsJson = '{not-json';
      final execution =
          JobExecution()
            ..firestoreId = 'execution-1'
            ..actionsJson = '[{}]';
      final module =
          JobModuleInstance()
            ..firestoreId = 'module-1'
            ..actionsJson = '"not-an-array"';

      for (final read in [
        maintenance.actionsReadResult,
        execution.actionsReadResult,
        module.actionsReadResult,
      ]) {
        expect(read.isValid, isFalse);
        expect(read.entries, isEmpty);
      }
      expect(() => maintenance.actions, throwsA(isA<FormatException>()));
      expect(() => execution.actions, throwsA(isA<FormatException>()));
      expect(() => module.actions, throwsA(isA<FormatException>()));
    });

    test(
      'wrong canonical payload types are rejected at remote map boundary',
      () {
        expect(
          () =>
              JobExecution.fromMap({'actionsJson': <dynamic>[]}, 'execution-1'),
          throwsA(isA<PersistedDataFormatException>()),
        );
        expect(
          () => JobModuleInstance.fromMap({
            'actionsJson': <dynamic>[],
          }, 'module-1'),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test('nested corrupt actions invalidate the whole resolution history', () {
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-history'
            ..resolutionHistoryJson = jsonEncode([
              {'resolvedAt': '2026-08-05T08:00:00.000Z', 'actionsJson': '[{}]'},
            ]);

      expect(record.resolutionHistoryReadResult.isValid, isFalse);
      expect(record.resolutionHistoryReadResult.entries, isEmpty);
    });

    testWidgets('module card shows repair state instead of a zero count', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 8, 5, 8);
      final module =
          JobModuleInstance()
            ..firestoreId = 'module-ui'
            ..moduleTitle = 'Hydraulic checks'
            ..assetType = AssetType.base
            ..assetNumber = 1
            ..status = JobModuleStatus.draftSaved
            ..useMode = JobModuleUseMode.scheduledPM
            ..discipline = JobModuleDiscipline.mechanical
            ..safetyClass = JobModuleSafetyClass.normal
            ..createdAt = now
            ..updatedAt = now
            ..actionsJson = '{not-json';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: JobModuleCard(module: module))),
      );

      expect(find.text('Actions need repair'), findsOneWidget);
      expect(find.text('0 actions'), findsNothing);
    });

    testWidgets('resolve UI exposes corrupt actions and blocks resolution', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-ui'
            ..assetType = AssetType.base
            ..assetNumber = 1
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Malformed action witness'
            ..routedTo = RoutedTo.operations
            ..startDate = now.subtract(const Duration(hours: 1))
            ..createdAt = now.subtract(const Duration(hours: 1))
            ..updatedAt = now
            ..actionsJson = '[{}]'
            ..resolutionHistoryJson = '[]';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(null),
            ),
          ],
          child: MaterialApp(home: ResolveForm(ticket: record)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved action evidence needs repair'), findsOneWidget);
      expect(
        find.textContaining('No actions were discarded or replaced'),
        findsOneWidget,
      );

      await tester.tap(find.text('Mark as Resolved'));
      await tester.pump();
      expect(
        find.text('Cannot resolve: saved action evidence needs repair.'),
        findsOneWidget,
      );
      expect(record.isResolved, isFalse);
    });

    test('source no longer contains silent action replacement fallbacks', () {
      final actionModel =
          File(
            'lib/features/planned_maintenance/models/component_action_model.dart',
          ).readAsStringSync();
      final maintenanceBridge =
          File(
            'functions/src/maintenanceWorkflow/maintenanceBridge.ts',
          ).readAsStringSync();
      final plannedDetail =
          File(
            'lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart',
          ).readAsStringSync();

      expect(actionModel, isNot(contains('catch (_) {\n      return [];')));
      expect(
        actionModel,
        contains('createdAt: readRequiredPersistedDateTime('),
      );
      expect(maintenanceBridge, isNot(contains('history = [];')));
      expect(
        maintenanceBridge,
        contains('maintenance-resolution-history-invalid'),
      );
      expect(plannedDetail, contains('Actions unavailable'));
      expect(plannedDetail, isNot(contains('execution.actions.isEmpty')));
    });
  });
}
