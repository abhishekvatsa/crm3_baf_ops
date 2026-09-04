import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final unavailable in [
    'missing',
    'wrong-workflow',
    'deleted',
    'failed-read',
  ]) {
    testWidgets(
      'unavailable revised request stays on its source ($unavailable)',
      (tester) async {
        final original = _compliance(status: 'superseded', version: 3)
          ..supersededById = 'revised-request';
        final successor =
            _compliance(status: 'acknowledged', version: 1)
              ..firestoreId = 'revised-request'
              ..isDeleted = unavailable == 'deleted'
              ..linkedWorkflowId =
                  unavailable == 'wrong-workflow'
                      ? 'other'
                      : original.linkedWorkflowId;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream.value(_instrumentationActor()),
              ),
              workflowComplianceRecordProvider.overrideWith((ref, scope) async {
                if (scope.complianceId != 'revised-request') return original;
                if (unavailable == 'failed-read') throw StateError('Offline');
                return unavailable == 'missing' ? null : successor;
              }),
              workflowAuthoritativeRecordProvider.overrideWith(
                (ref, scope) async => _aggregate(4),
              ),
              workflowCommandControllerProvider.overrideWith(
                (ref) => WorkflowCommandController.forTesting(
                  executeCommand: (_) async => throw StateError('Read only'),
                  pullProjections: () async {},
                ),
              ),
            ],
            child: MaterialApp(
              theme: BafAppTheme.light,
              home: ComplianceDetailScreen(record: original),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Open agreed revised request'));
        await tester.tap(find.text('Open agreed revised request'));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not open revised request. Refresh and try again.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ComplianceDetailScreen>(
                find.byType(ComplianceDetailScreen),
              )
              .record
              .firestoreId,
          original.firestoreId,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('agreed revision opens the exact successor request', (
    tester,
  ) async {
    final original = _compliance(status: 'superseded', version: 3)
      ..supersededById = 'revised-request';
    final revised =
        _compliance(status: 'acknowledged', version: 1)
          ..firestoreId = 'revised-request'
          ..title = 'Agreed crane positioning';
    final readIds = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_instrumentationActor()),
          ),
          workflowComplianceRecordProvider.overrideWith((ref, scope) async {
            readIds.add(scope.complianceId);
            return scope.complianceId == 'revised-request' ? revised : original;
          }),
          workflowAuthoritativeRecordProvider.overrideWith(
            (ref, scope) async => _aggregate(4),
          ),
          workflowCommandControllerProvider.overrideWith(
            (ref) => WorkflowCommandController.forTesting(
              executeCommand: (_) async => throw StateError('Read only'),
              pullProjections: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: ComplianceDetailScreen(record: original),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open agreed revised request'));
    await tester.tap(find.text('Open agreed revised request'));
    await tester.pumpAndSettle();
    expect(readIds, contains('revised-request'));
    expect(find.text('Agreed crane positioning'), findsWidgets);
    expect(find.text('Mark complied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request displays completion actor, time and retained notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final record =
        _compliance(status: 'confirmedClosed', version: 6)
          ..compliedByName = 'Operations One'
          ..compliedAt = DateTime(2026, 9, 4, 10, 15)
          ..complianceNote = 'Crane positioned on stand 2.'
          ..confirmedByName = 'Mechanical One'
          ..confirmedAt = DateTime(2026, 9, 4, 10, 20)
          ..confirmNote = 'Placement accepted.';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_instrumentationActor()),
          ),
          workflowComplianceRecordProvider.overrideWith(
            (ref, scope) async => record,
          ),
          workflowAuthoritativeRecordProvider.overrideWith(
            (ref, scope) async => _aggregate(6),
          ),
          workflowCommandControllerProvider.overrideWith(
            (ref) => WorkflowCommandController.forTesting(
              executeCommand: (_) async => throw StateError('Read only'),
              pullProjections: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: ComplianceDetailScreen(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Operations One - 2026-09-04 10:15'),
      findsOneWidget,
    );
    expect(find.text('Crane positioned on stand 2.'), findsOneWidget);
    expect(
      find.textContaining('Mechanical One - 2026-09-04 10:20'),
      findsOneWidget,
    );
    expect(find.text('Placement accepted.'), findsOneWidget);
    expect(find.text('Mark complied'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed command is visible and retry uses freshly read workflow state',
    (tester) async {
      var record = _compliance(status: 'raised', version: 1);
      var version = 1;
      final commands = <WorkflowCommand>[];
      var reads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_instrumentationActor()),
            ),
            workflowComplianceRecordProvider.overrideWith((ref, scope) async {
              reads++;
              return record;
            }),
            workflowAuthoritativeRecordProvider.overrideWith(
              (ref, scope) async => _aggregate(version),
            ),
            workflowCommandControllerProvider.overrideWith(
              (ref) => WorkflowCommandController.forTesting(
                executeCommand: (command) async {
                  commands.add(command);
                  if (commands.length == 1) {
                    record = _compliance(status: 'acknowledged', version: 4);
                    version = 4;
                    throw const WorkflowException(
                      WorkflowErrorCode.failedPrecondition,
                      'Another phone already acknowledged.',
                    );
                  }
                  return _receipt(
                    command,
                    resultKey: 'compliance-complied',
                    aggregateVersion: 5,
                  );
                },
                pullProjections: () async {},
              ),
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: ComplianceDetailScreen(record: record),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Request not confirmed:'), findsOneWidget);
      expect(reads, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Mark complied'));
      await tester.tap(find.text('Mark complied'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Operations completed the work.',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(commands.last.expectedVersion, 4);
      expect(tester.takeException(), isNull);
    },
  );

  for (final pendingRevision in [false, true]) {
    testWidgets(
      'deferment shows one completion path; pending revision=$pendingRevision',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final record =
            _compliance(status: 'acknowledged', version: 2)
              ..targetLaneKey = 'oprn'
              ..conditionTypeKey = 'chargeComplete'
              ..conditionRef = '12345'
              ..requestPurposeKey = 'deferment'
              ..defermentBasisKey = 'ongoingCycle'
              ..counterRevisedDescription =
                  pendingRevision ? 'Wait for crane release too.' : null;
        final actor = AppUser(
          uid: 'operations-1',
          name: 'Operator',
          email: 'operator@example.test',
          roles: [AppRole.operations],
          isApproved: true,
          createdAt: DateTime.utc(2026),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => Stream.value(actor)),
              workflowComplianceRecordProvider.overrideWith(
                (ref, scope) async => record,
              ),
              workflowAuthoritativeRecordProvider.overrideWith(
                (ref, scope) async => _aggregate(2),
              ),
              workflowCommandControllerProvider.overrideWith(
                (ref) => WorkflowCommandController.forTesting(
                  executeCommand:
                      (_) async => throw StateError('No command expected'),
                  pullProjections: () async {},
                ),
              ),
            ],
            child: MaterialApp(
              theme: BafAppTheme.light,
              home: ComplianceDetailScreen(record: record),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(find.text('Mark complied'), findsNothing);
        expect(
          find.text('Confirm release condition met'),
          pendingRevision ? findsNothing : findsOneWidget,
        );
        if (pendingRevision) {
          expect(
            find.text('Revised condition awaiting MECH decision'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Accept revised condition'),
                )
                .onPressed,
            isNull,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets(
    'workflow read failure keeps trusted compliance evidence readable',
    (tester) async {
      final record = _compliance(status: 'acknowledged', version: 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_instrumentationActor()),
            ),
            workflowComplianceRecordProvider.overrideWith(
              (ref, scope) async => record,
            ),
            workflowAuthoritativeRecordProvider.overrideWith(
              (ref, scope) => Future<WorkflowAggregateRecord?>.error(
                StateError('server read unavailable'),
              ),
            ),
            workflowCommandControllerProvider.overrideWith((ref) {
              return WorkflowCommandController.forTesting(
                executeCommand: (command) async {
                  throw StateError('Actions must remain disabled.');
                },
                pullProjections: () async {},
              );
            }),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: ComplianceDetailScreen(record: record),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Build 19 operations support'), findsWidgets);
      expect(find.text('Software-only device validation.'), findsOneWidget);
      expect(find.text('Request context'), findsOneWidget);
      expect(find.text('Actions temporarily unavailable'), findsOneWidget);
      expect(find.text('Mark complied'), findsNothing);
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
