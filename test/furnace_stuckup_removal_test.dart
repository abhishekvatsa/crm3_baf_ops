import 'dart:async';

import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_stuckup_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(AppRole role, {bool approved = true}) => AppUser(
  uid: 'witness-1',
  name: 'Removal witness',
  email: 'witness@example.test',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 8, 1),
);

FurnaceStuckupRecord _case({bool released = false}) => FurnaceStuckupRecord(
  id: 'case-1',
  ticketId: 'case-1',
  version: released ? 2 : 1,
  obstructionStatus:
      released
          ? FurnaceStuckupObstructionStatus.released
          : FurnaceStuckupObstructionStatus.active,
  adjudicationStatus: FurnaceStuckupAdjudicationStatus.pending,
  suspectedCause: FurnaceStuckupCause.innerCoverBulging,
  confirmedCause: null,
  furnaceAssetInstanceId: 'furnace-12',
  furnaceAssetNumber: 12,
  baseAssetInstanceId: 'base-117',
  baseAssetNumber: 117,
  innerCoverId: 'inner-gr26',
  innerCoverSerialNumber: 'GR26',
  operatingContext: FurnaceStuckupOperatingContext.postAnnealingRemoval,
  chargeNoAtEvent: 12345,
  reportedAt: DateTime.utc(2026, 8, 20, 4),
  reportedByName: 'Operator',
  releasedAt: released ? DateTime.utc(2026, 8, 20, 5) : null,
  releaseNotes: released ? 'Furnace lifted clear of Base 117.' : null,
  adjudicatedAt: null,
  adjudicationNotes: null,
  conditionDeclarationId: null,
  updatedAt: DateTime.utc(2026, 8, 20, released ? 5 : 4),
);

void main() {
  const allowed = {
    AppRole.admin,
    AppRole.si,
    AppRole.contractSupervisor,
    AppRole.shiftSupervisor,
    AppRole.operations,
  };
  for (final role in AppRole.values) {
    test('${role.name} removal permission requires approval', () {
      expect(_user(role).canReleaseFurnaceStuckup, allowed.contains(role));
      expect(_user(role, approved: false).canReleaseFurnaceStuckup, isFalse);
    });
  }

  test(
    'Operations removal permission does not grant other maintenance powers',
    () {
      final user = _user(AppRole.operations);
      expect(user.canAdjudicateFurnaceStuckup, isFalse);
      expect(user.canRestoreAssetOperationalCondition, isFalse);
      expect(user.canFinalizeMaintenanceIssue([RoutedTo.mechanical]), isFalse);
      expect(user.canCloseMaintenanceIssueWithoutResolution, isFalse);
    },
  );

  for (final width in [360.0, 412.0]) {
    testWidgets('Operations confirms removal at phone width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final records = StreamController<List<FurnaceStuckupRecord>>();
      addTearDown(records.close);
      final response = Completer<WorkflowCommandReceipt>();
      final commands = <WorkflowCommand>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_user(AppRole.operations)),
            ),
            furnaceStuckupCasesProvider.overrideWith((ref) => records.stream),
            assetConditionDeclarationsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            workflowCommandControllerProvider.overrideWith(
              (ref) => WorkflowCommandController.forTesting(
                executeCommand: (command) {
                  commands.add(command);
                  return response.future;
                },
                pullProjections: () async {},
              ),
            ),
          ],
          child: const MaterialApp(home: FurnaceStuckupBoard()),
        ),
      );
      await tester.pump();
      records.add([_case()]);
      await tester.pumpAndSettle();
      expect(find.text('Adjudicate cause'), findsNothing);
      await tester.ensureVisible(find.text('Confirm removal'));
      await tester.tap(find.text('Confirm removal'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm furnace removal'), findsOneWidget);
      expect(
        find.textContaining('the maintenance issue remains accountable'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm removal').last,
      );
      await tester.pump();
      expect(commands, isEmpty);
      await tester.enterText(
        find.byType(TextField),
        'Furnace lifted clear of Base 117.',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm removal').last,
      );
      await tester.pumpAndSettle();
      expect(commands, hasLength(1));
      final command = commands.single;
      expect(command.type, WorkflowCommandType.releaseFurnaceStuckup);
      expect(command.aggregateId, 'case-1');
      expect(command.expectedVersion, 1);
      expect(command.payload, {
        'releaseNotes': 'Furnace lifted clear of Base 117.',
      });
      expect(find.text('Temporarily blocked'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm removal'),
            )
            .onPressed,
        isNull,
      );

      response.complete(
        WorkflowCommandReceipt(
          commandId: command.commandId,
          resultKey: 'furnace-stuckup-released',
          aggregateVersion: 2,
          result: const {'caseId': 'case-1', 'auditId': 'audit-1'},
          appliedAt: DateTime.utc(2026, 8, 20, 5),
        ),
      );
      records.add([_case(released: true)]);
      await tester.pumpAndSettle();
      expect(find.text('Confirm removal'), findsNothing);
      expect(find.text('Furnace removal confirmed.'), findsOneWidget);
      await tester.tap(find.text('Cause 1'));
      await tester.pumpAndSettle();
      expect(find.text('Released'), findsOneWidget);
      expect(find.text('Cause pending'), findsWidgets);
      expect(find.text('Adjudicate cause'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('server rejection leaves the obstruction active and retryable', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(AppRole.operations)),
          ),
          furnaceStuckupCasesProvider.overrideWith(
            (ref) => Stream.value([_case()]),
          ),
          assetConditionDeclarationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          workflowCommandControllerProvider.overrideWith(
            (ref) => WorkflowCommandController.forTesting(
              executeCommand: (_) async {
                calls++;
                throw StateError('Permission revoked');
              },
              pullProjections: () async {},
            ),
          ),
        ],
        child: const MaterialApp(home: FurnaceStuckupBoard()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm removal'));
    await tester.tap(find.text('Confirm removal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Furnace lifted clear.');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm removal').last);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.textContaining('The governed action could not be completed'),
      findsOneWidget,
    );
    expect(find.text('Furnace removal confirmed.'), findsNothing);
    expect(find.text('Temporarily blocked'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm removal'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
