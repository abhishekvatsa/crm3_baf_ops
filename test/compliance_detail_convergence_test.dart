import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'successful compliance actions refresh record and advance receipt version',
    (tester) async {
      var aggregateVersion = 1;
      var currentRecord = _compliance(status: 'raised', version: 1);
      var pointReads = 0;
      var aggregateReads = 0;
      final commands = <WorkflowCommand>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_instrumentationActor()),
            ),
            workflowComplianceRecordProvider.overrideWith((ref, scope) async {
              pointReads += 1;
              return currentRecord;
            }),
            workflowAuthoritativeRecordProvider.overrideWith((
              ref,
              scope,
            ) async {
              aggregateReads += 1;
              return _aggregate(aggregateVersion);
            }),
            workflowCommandControllerProvider.overrideWith((ref) {
              return WorkflowCommandController.forTesting(
                executeCommand: (command) async {
                  commands.add(command);
                  switch (command.type) {
                    case WorkflowCommandType.acknowledgeCompliance:
                      aggregateVersion = 2;
                      currentRecord = _compliance(
                        status: 'acknowledged',
                        version: 2,
                      );
                      return _receipt(
                        command,
                        resultKey: 'compliance-acknowledged',
                        aggregateVersion: aggregateVersion,
                      );
                    case WorkflowCommandType.markComplianceComplied:
                      aggregateVersion = 3;
                      currentRecord = _compliance(
                        status: 'complied',
                        version: 3,
                      );
                      return _receipt(
                        command,
                        resultKey: 'compliance-complied',
                        aggregateVersion: aggregateVersion,
                      );
                    default:
                      throw StateError('Unexpected command ${command.type}');
                  }
                },
                pullProjections: () async {},
              );
            }),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: ComplianceDetailScreen(record: currentRecord),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge'), findsOneWidget);
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(find.text('Mark complied'), findsOneWidget);
      await tester.tap(find.text('Mark complied'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Software-only device validation evidence.',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(commands, hasLength(2));
      expect(commands[0].expectedVersion, 1);
      expect(commands[1].expectedVersion, 2);
      expect(commands[1].payload['complianceId'], 'compliance-device-1');
      expect(pointReads, greaterThanOrEqualTo(3));
      expect(aggregateReads, greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopened detail uses server workflow version instead of stale local aggregate',
    (tester) async {
      WorkflowCommand? sent;
      final acknowledged = _compliance(status: 'acknowledged', version: 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_instrumentationActor()),
            ),
            workflowComplianceRecordProvider.overrideWith(
              (ref, scope) async => acknowledged,
            ),
            workflowAuthoritativeRecordProvider.overrideWith(
              (ref, scope) async => _aggregate(2),
            ),
            workflowAggregateProvider.overrideWith((ref, workflowId) {
              throw StateError(
                'The local aggregate must not authorize actions.',
              );
            }),
            workflowCommandControllerProvider.overrideWith((ref) {
              return WorkflowCommandController.forTesting(
                executeCommand: (command) async {
                  sent = command;
                  return _receipt(
                    command,
                    resultKey: 'compliance-complied',
                    aggregateVersion: 3,
                  );
                },
                pullProjections: () async {},
              );
            }),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: ComplianceDetailScreen(record: acknowledged),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark complied'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Completion evidence.');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(sent?.type, WorkflowCommandType.markComplianceComplied);
      expect(sent?.expectedVersion, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

AppUser _instrumentationActor() => AppUser(
  uid: 'instrumentation-1',
  name: 'Instrumentation One',
  email: 'instrumentation@example.com',
  roles: const <AppRole>[AppRole.seniorInstrumentation],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 30),
);

ComplianceRequestRecord _compliance({
  required String status,
  required int version,
}) =>
    ComplianceRequestRecord()
      ..firestoreId = 'compliance-device-1'
      ..isSynced = true
      ..version = version
      ..title = 'Build 19 operations support'
      ..description = 'Software-only device validation.'
      ..originLaneKey = 'mech'
      ..targetLaneKey = 'inst'
      ..statusKey = status
      ..conditionTypeKey = 'manual'
      ..raisedByUid = 'mechanical-1'
      ..raisedByName = 'Mechanical One'
      ..linkedWorkflowId = 'workflow-device-1';

WorkflowAggregateRecord _aggregate(int version) =>
    WorkflowAggregateRecord()
      ..firestoreId = 'workflow-device-1'
      ..jobExecutionFirestoreId = 'issue-device-1'
      ..assetTypeKey = 'forcedCooler'
      ..assetNumber = 1
      ..statusKey = 'awaitingCompliance'
      ..version = version
      ..laneSetVersion = 1
      ..laneSetFinalizedAt = DateTime.utc(2026, 8, 30)
      ..activeRedWork = false
      ..awaitingPreparation = false
      ..cancelled = false
      ..createdAt = DateTime.utc(2026, 8, 30)
      ..updatedAt = DateTime.utc(2026, 8, 30, 1, version);

WorkflowCommandReceipt _receipt(
  WorkflowCommand command, {
  required String resultKey,
  required int aggregateVersion,
}) => WorkflowCommandReceipt(
  commandId: command.commandId,
  resultKey: resultKey,
  aggregateVersion: aggregateVersion,
  result: const <String, Object?>{'complianceId': 'compliance-device-1'},
  appliedAt: DateTime.utc(2026, 8, 30, 2, aggregateVersion),
);
