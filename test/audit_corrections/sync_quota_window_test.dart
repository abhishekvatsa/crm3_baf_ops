import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_outbox_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../tool/test_support/test_isar_core.dart';

/// The sync push path submits through `WorkflowCommandGateway` directly, not
/// through `WorkflowOnlineExecutor`, so nothing else stores a retry deadline
/// for it. Declining to retry inside one `_retry` loop is only half of the
/// contract: without a stored window, the next sync invocation resubmits
/// immediately and the server's delay was never honoured.
///
/// These cover the boundary the sync service actually relies on — the stored
/// window and the identity it is keyed by — across separate invocations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Directory directory;
  late Isar database;
  late WorkflowRepository deadlines;

  final t0 = DateTime.utc(2026, 9, 11, 8);
  const ticketId = 'ticket-9182';
  const commandId = 'createMaintenanceTicket_$ticketId';

  const quotaRefusal = WorkflowException(
    WorkflowErrorCode.resourceExhausted,
    'Quota temporarily exhausted.',
    details: <String, Object?>{'retryAfterSeconds': 1800},
  );

  final command = WorkflowCommand(
    commandId: commandId,
    type: WorkflowCommandType.createMaintenanceTicket,
    aggregateId: ticketId,
    expectedVersion: 0,
    payload: const <String, Object?>{'ticketId': ticketId},
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_quota_');
    database = await Isar.open(
      <CollectionSchema<dynamic>>[
        WorkflowCommandRecordSchema,
        WorkflowCommandReceiptRecordSchema,
      ],
      directory: directory.path,
      name: 'sync_quota',
      inspector: false,
    );
    deadlines = IsarWorkflowRepository(database);
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  // What the push path writes when the gateway refuses on quota, and reads
  // before it submits. Mirrors the service helpers, which are private to the
  // SyncService extension.
  Future<void> recordWindow(DateTime now) async {
    const policy = WorkflowRetryPolicy();
    final existing = await deadlines.getRetryCommand(command.commandId);
    if (existing != null && existing.stateKey != 'ready') return;
    await deadlines.saveRetryCommand(
      (existing ?? WorkflowCommandRecord())
        ..commandId = command.commandId
        ..aggregateId = command.aggregateId
        ..commandTypeKey = command.type.name
        ..expectedVersion = command.expectedVersion
        ..payloadJson = '{"ticketId":"$ticketId"}'
        ..stateKey = 'ready'
        ..createdLocallyAt = existing?.createdLocallyAt ?? now
        ..lastAttemptAt = now
        ..nextRetryAt = now.add(
          policy.delayForFailure(quotaRefusal, existing?.attemptCount ?? 0),
        ),
    );
  }

  Future<bool> windowOpen(DateTime now) async {
    final existing = await deadlines.getRetryCommand(command.commandId);
    final deadline = existing?.nextRetryAt?.toUtc();
    return deadline != null && deadline.isAfter(now.toUtc());
  }

  test('a quota refusal suppresses the next sync invocation, not just this one', () async {
    // First invocation: nothing stored, so the ticket is eligible.
    expect(await windowOpen(t0), isFalse);

    // The gateway refuses on quota and the window is recorded.
    await recordWindow(t0);

    // Second invocation, before the window closes. This is the case the
    // short-loop predicate alone does not cover: a separate call, with the
    // in-flight loop long gone.
    expect(await windowOpen(t0.add(const Duration(minutes: 5))), isTrue);
    expect(await windowOpen(t0.add(const Duration(minutes: 29))), isTrue);

    // Once the server's own window has passed, it becomes eligible again.
    expect(await windowOpen(t0.add(const Duration(minutes: 31))), isFalse);
  });

  test('the window is keyed by an identity the next run derives the same way', () async {
    // The stored deadline is only found again if the command id is stable.
    // It is derived from the ticket's remote id, not generated per attempt.
    await recordWindow(t0);
    final stored = await deadlines.getRetryCommand(commandId);
    expect(stored, isNotNull);
    expect(stored!.commandId, commandId);
    expect(stored.aggregateId, ticketId);

    // The same value the builder would use for the same ticket.
    expect(maintenanceIssueCreateCommandIdForTicket(ticketId), commandId);
  });

  test('the deferred request stays pending and is not turned into attention', () async {
    await recordWindow(t0);
    final inventory = await deadlines.readOutcomeInventory();
    // It will progress on its own once the window closes, so it belongs in
    // retrying — not in the counts that ask an operator to intervene.
    expect(inventory.retrying, 1);
    expect(inventory.rejected, 0);
    expect(inventory.manualReview, 0);
    expect(describeWorkflowAttention(inventory), isNull);
  });

  test('a row already owned by the executor is left alone', () async {
    // A command in a real lifecycle state belongs to the executor. The sync
    // path must not overwrite its bookkeeping with a bare deadline.
    await deadlines.saveRetryCommand(
      WorkflowCommandRecord()
        ..commandId = commandId
        ..aggregateId = ticketId
        ..commandTypeKey = command.type.name
        ..expectedVersion = 0
        ..payloadJson = '{"ticketId":"$ticketId"}'
        ..stateKey = 'uncertainOutcome'
        ..attemptCount = 4
        ..createdLocallyAt = t0.subtract(const Duration(hours: 2))
        ..nextRetryAt = t0.add(const Duration(minutes: 2)),
    );
    await recordWindow(t0);
    final stored = await deadlines.getRetryCommand(commandId);
    expect(stored!.stateKey, 'uncertainOutcome');
    expect(stored.attemptCount, 4);
    expect(
      stored.nextRetryAt!.toUtc(),
      t0.add(const Duration(minutes: 2)),
      reason: 'the executor owns this row',
    );
  });

  test('a deferred row is not claimed by the uncertain-retry service', () async {
    // `ready` is deliberately not a claimable state. If it were, two systems
    // would be driving the same command.
    await recordWindow(t0);
    final claimed = await (deadlines as IsarWorkflowRepository)
        .claimRetryableCommands(
          now: t0.add(const Duration(hours: 1)),
          lease: const Duration(minutes: 5),
        );
    expect(claimed, isEmpty);
  });
}
