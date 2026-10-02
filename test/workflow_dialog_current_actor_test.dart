import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/frequent_issue_definition.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/frequent_issue_catalogue_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/frequent_issue_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _actions = ['compliance', 'deploy', 'reconcile', 'edit', 'retire'];

void main() {
  for (final action in _actions) {
    for (final interruption in [
      'account switch',
      'refresh',
      'error',
      'role loss',
    ]) {
      testWidgets('$action queued confirmation blocks $interruption', (
        tester,
      ) async {
        final harness = _Harness(action);
        await harness.pump(tester);
        await harness.open(tester);
        final confirm = tester.widget<FilledButton>(harness.confirm).onPressed!;
        await harness.interrupt(tester, interruption);
        // A callback already queued before the rebuild must recheck admission.
        confirm();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(harness.commands, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$action dialog preserves intent and resumes only for origin', (
      tester,
    ) async {
      final harness = _Harness(action);
      await harness.pump(tester);
      await harness.open(tester);
      await harness.interrupt(tester, 'account switch');
      expect(find.text('Account verification required'), findsOneWidget);
      expect(harness.confirm, findsNothing);
      harness.actors.add(_actor());
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsNothing);
      if (action == 'compliance') {
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Retained completion evidence',
        );
      }
      if (action == 'edit') {
        expect(find.text('Retained issue title'), findsOneWidget);
      }
      await tester.tap(harness.confirm);
      await tester.pumpAndSettle();
      expect(harness.commands, hasLength(1));
      final sent = harness.commands.single;
      switch (action) {
        case 'compliance':
          expect(sent.type, WorkflowCommandType.markComplianceComplied);
          expect(sent.aggregateId, 'workflow-test');
          expect(sent.expectedVersion, 10);
          expect(sent.payload, {
            'complianceId': 'compliance-test',
            'expectedComplianceVersion': 7,
            'note': 'Retained completion evidence',
          });
        case 'deploy':
        case 'reconcile':
          expect(
            sent.type,
            action == 'deploy'
                ? WorkflowCommandType.deployEquipment
                : WorkflowCommandType.reconcileEquipment,
          );
          expect(sent.aggregateId, 'equipment_furnace_7');
          expect(sent.expectedVersion, 12);
          expect(sent.payload, {'assetTypeKey': 'furnace', 'assetNumber': 7});
        case 'edit':
          expect(sent.type, WorkflowCommandType.upsertFrequentIssueDefinition);
          expect(sent.aggregateId, 'definition-test');
          expect(sent.expectedVersion, 3);
          final definition = sent.payload['definition'] as Map;
          expect(definition['title'], 'Retained issue title');
          expect(definition['applicableAssetTypeKeys'], ['base']);
          expect(definition['defaultRouteKey'], 'mechanical');
        case 'retire':
          expect(
            sent.type,
            WorkflowCommandType.setFrequentIssueDefinitionStatus,
          );
          expect(sent.aggregateId, 'definition-test');
          expect(sent.expectedVersion, 3);
          expect(sent.payload, {
            'status': 'retired',
            'reason': 'Retired through the governed catalogue.',
          });
      }
      expect(tester.takeException(), isNull);
    });
  }
}

AppUser _actor({
  String uid = 'origin-admin',
  bool approved = true,
  AppRole role = AppRole.admin,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

class _Harness {
  _Harness(this.action);
  final String action;
  final actors = StreamController<AppUser?>.broadcast();
  final commands = <WorkflowCommand>[];
  late ProviderContainer container;
  bool firstAuthority = true;
  final record = ComplianceRequestRecord()
    ..firestoreId = 'compliance-test'
    ..isSynced = true
    ..version = 7
    ..title = 'Synthetic support'
    ..description = 'Isolated widget fixture'
    ..originLaneKey = 'mech'
    ..targetLaneKey = 'inst'
    ..statusKey = 'acknowledged'
    ..conditionTypeKey = 'manual'
    ..raisedByUid = 'mechanical-test'
    ..raisedByName = 'Mechanical'
    ..linkedWorkflowId = 'workflow-test';
  final workflow = WorkflowAggregateRecord()
    ..firestoreId = 'workflow-test'
    ..jobExecutionFirestoreId = 'issue-test'
    ..assetTypeKey = 'forcedCooler'
    ..assetNumber = 1
    ..statusKey = 'awaitingCompliance'
    ..version = 10
    ..laneSetVersion = 1
    ..laneSetFinalizedAt = DateTime.utc(2026)
    ..activeRedWork = false
    ..awaitingPreparation = false
    ..cancelled = false
    ..createdAt = DateTime.utc(2026)
    ..updatedAt = DateTime.utc(2026);
  final equipment = EquipmentStatusRecord()
    ..firestoreId = 'furnace_7'
    ..assetTypeKey = 'furnace'
    ..assetNumber = 7
    ..stateKey = 'available'
    ..version = 12;

  Finder get confirm => find.widgetWithText(FilledButton, switch (action) {
    'compliance' => 'Continue',
    'deploy' => 'Deploy',
    'reconcile' => 'Reconcile',
    'edit' => 'Save',
    _ => 'Retire',
  });

  Future<void> pump(WidgetTester tester) async {
    addTearDown(actors.close);
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) async* {
            if (firstAuthority) {
              firstAuthority = false;
              yield _actor();
            }
            yield* actors.stream;
          }),
          workflowComplianceRecordProvider.overrideWith(
            (_, __) async => record,
          ),
          workflowAuthoritativeRecordProvider.overrideWith(
            (_, __) async => workflow,
          ),
          equipmentStatusProvider.overrideWith(
            (_, __) => Stream.value([equipment]),
          ),
          frequentIssueDefinitionsProvider.overrideWith(
            (_) => Stream.value([_definition()]),
          ),
          workflowCommandControllerProvider.overrideWith(
            (_) => WorkflowCommandController.forTesting(
              executeCommand: (command) async {
                commands.add(command);
                return WorkflowCommandReceipt(
                  commandId: command.commandId,
                  resultKey: 'accepted',
                  aggregateVersion: command.expectedVersion + 1,
                  result: const {},
                  appliedAt: DateTime.utc(2026),
                );
              },
              pullProjections: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: switch (action) {
            'compliance' => ComplianceDetailScreen(record: record),
            'deploy' || 'reconcile' => const EquipmentStatusBoard(),
            _ => const FrequentIssueCatalogueScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  Future<void> open(WidgetTester tester) async {
    final opener = switch (action) {
      'compliance' => find.text('Mark complied'),
      'deploy' => find.text('Put in service'),
      'reconcile' => find.byTooltip('Reconcile derived equipment state'),
      'edit' => find.byTooltip('Edit definition'),
      _ => find.byTooltip('Retire'),
    };
    await tester.ensureVisible(opener);
    await tester.tap(opener);
    await tester.pumpAndSettle();
    if (action == 'compliance') {
      await tester.enterText(
        find.byType(TextField),
        'Retained completion evidence',
      );
    }
    if (action == 'edit') {
      final title = find.widgetWithText(TextFormField, 'Issue name');
      await tester.enterText(title, 'Retained issue title');
    }
    await tester.pump();
  }

  Future<void> interrupt(WidgetTester tester, String interruption) async {
    switch (interruption) {
      case 'account switch':
        actors.add(_actor(uid: 'different-admin'));
      case 'refresh':
        container.invalidate(currentAppUserProvider);
      case 'error':
        actors.addError(StateError('Synthetic authority unavailable'));
      case 'role loss':
        actors.add(_actor(role: AppRole.seniorMechanical));
    }
    await tester.pump();
    await tester.pump();
  }
}

FrequentIssueDefinition _definition() => FrequentIssueDefinition(
  id: 'definition-test',
  version: 3,
  status: FrequentIssueDefinitionStatus.active,
  code: 'SYNTHETIC',
  title: 'Synthetic issue',
  description: 'Synthetic test definition',
  applicableAssetTypeKeys: const ['base'],
  applicableAssetClassIds: const [],
  applicableComponentNodeIds: const [],
  suggestedSeverityKey: 'normal',
  suggestedMaintenanceTypeKey: 'breakdown',
  defaultRouteKey: 'mechanical',
  requiredEvidenceFields: const [],
  aliases: const [],
  createdAt: DateTime.utc(2026),
  createdByUid: 'origin-admin',
  createdByName: 'Origin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'origin-admin',
  updatedByName: 'Origin',
);
