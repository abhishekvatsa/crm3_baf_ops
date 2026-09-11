import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_outbox_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../tool/test_support/test_isar_core.dart';

/// What the bounded quota deferral actually guarantees.
///
/// A quota refusal from the callable admission gate is a refusal *before
/// execution*: `executeWithCallableAbuseControl` awaits `admitRequest` and
/// throws there, so `execute()` — and with it the command handler, its
/// transaction and its receipt — never runs. That is why such a refusal does
/// not spend an uncertain-dispatch attempt.
///
/// It is deliberately NOT a claim that no earlier attempt was accepted. Those
/// are separate questions and this suite keeps them separate: a later quota
/// refusal must neither erase an earlier uncertain outcome nor override an
/// accepted receipt.
///
/// Isar returns DateTime values in local time and Dart's DateTime.== requires
/// a matching isUtc flag as well as the same instant, so comparisons normalise
/// before asserting.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Directory directory;
  late Isar database;
  late IsarWorkflowRepository repository;

  // The clock the executor is given. The deferral window is measured from when
  // the request was first recorded locally, never from server acceptance.
  final t0 = DateTime.utc(2026, 9, 11, 8);
  const lease = Duration(minutes: 5);
  final command = WorkflowCommand(
    commandId: 'quota-boundary',
    type: WorkflowCommandType.acknowledgeMaintenanceTicket,
    aggregateId: 'ticket-fixture',
    expectedVersion: 1,
    payload: const <String, Object?>{'laneKey': 'mech'},
  );

  const quotaRefusal = WorkflowException(
    WorkflowErrorCode.resourceExhausted,
    'Quota temporarily exhausted.',
    details: <String, Object?>{'retryAfterSeconds': 1200},
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quota_boundary_');
    database = await Isar.open(
      <CollectionSchema<dynamic>>[
        WorkflowCommandRecordSchema,
        WorkflowCommandReceiptRecordSchema,
      ],
      directory: directory.path,
      name: 'quota_boundary',
      inspector: false,
    );
    repository = IsarWorkflowRepository(database);
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<void> seed({
    required Duration firstRecordedAgo,
    String stateKey = 'uncertainOutcome',
    int attemptCount = 3,
  }) {
    return repository.saveRetryCommand(
      WorkflowCommandRecord()
        ..commandId = command.commandId
        ..aggregateId = command.aggregateId
        ..commandTypeKey = command.type.name
        ..expectedVersion = command.expectedVersion
        ..payloadJson = '{"laneKey":"mech"}'
        ..stateKey = stateKey
        ..attemptCount = attemptCount
        ..createdLocallyAt = t0.subtract(firstRecordedAgo)
        ..nextRetryAt = t0.subtract(const Duration(minutes: 1)),
    );
  }

  // A fresh executor each time: nothing about the boundary is held in memory,
  // so a restart reads the same answer from the stored row.
  WorkflowOnlineExecutor executor(WorkflowCommandGateway gateway) =>
      WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: gateway,
        repository: repository,
        now: () => t0,
        checkConnectivity: () async => <ConnectivityResult>[
          ConnectivityResult.wifi,
        ],
        isNetworkBlocked: () async => false,
      );

  Future<WorkflowCommandRecord?> refuseOnQuota() async {
    final claimed = await repository.claimRetryableCommands(
      now: t0,
      lease: lease,
    );
    await expectLater(
      executor(_RefusingGateway(quotaRefusal)).execute(
        command,
        claimedAt: claimed.single.lastAttemptAt,
      ),
      throwsA(isA<WorkflowException>()),
    );
    return repository.getRetryCommand(command.commandId);
  }

  group('the deferral boundary', () {
    test('is measured from first local recording, not from this attempt', () async {
      await seed(
        firstRecordedAgo:
            WorkflowRetryPolicy.maxQuotaDeferral - const Duration(minutes: 1),
      );
      final within = await refuseOnQuota();
      expect(within!.stateKey, 'uncertainOutcome');
      expect(
        within.nextRetryAt!.toUtc(),
        t0.add(const Duration(seconds: 1200)),
      );

      await seed(
        firstRecordedAgo:
            WorkflowRetryPolicy.maxQuotaDeferral + const Duration(minutes: 1),
      );
      final beyond = await refuseOnQuota();
      expect(beyond!.stateKey, 'manualReview');
      expect(beyond.nextRetryAt, isNull);
    });

    test('survives repeated refusals rather than being reset by them', () async {
      // Each refusal rewrites the row. If any of them moved the start of the
      // window, a steadily refusing server could defer the same request for
      // ever in increments that each look reasonable.
      await seed(
        firstRecordedAgo:
            WorkflowRetryPolicy.maxQuotaDeferral - const Duration(minutes: 3),
      );
      final origin = (await repository.getRetryCommand(
        command.commandId,
      ))!.createdLocallyAt.toUtc();

      for (var round = 0; round < 3; round++) {
        final row = await refuseOnQuota();
        expect(row!.createdLocallyAt.toUtc(), origin);
        expect(row.attemptCount, 3, reason: 'a refusal is not a dispatch');
        // Make it due again without touching the window's origin.
        await repository.saveRetryCommand(
          row..nextRetryAt = t0.subtract(const Duration(minutes: 1)),
        );
      }
    });

    test('expiry asks for a person and keeps the work and its identity', () async {
      await seed(
        firstRecordedAgo:
            WorkflowRetryPolicy.maxQuotaDeferral + const Duration(minutes: 1),
      );
      final expired = await refuseOnQuota();
      expect(expired!.stateKey, 'manualReview');
      expect(expired.commandId, command.commandId);
      expect(expired.payloadJson, '{"laneKey":"mech"}');

      // Visible as attention rather than silently terminal.
      final inventory = await repository.readOutcomeInventory();
      expect(inventory.needingAction, greaterThan(0));
      expect(describeWorkflowAttention(inventory), isNotNull);
    });
  });

  group('a quota refusal and an earlier attempt are separate questions', () {
    test('it does not erase an earlier uncertain outcome', () async {
      // The row is already uncertain because a previous response was lost.
      // A later refusal-before-execution says nothing about that attempt.
      await seed(firstRecordedAgo: const Duration(hours: 1), attemptCount: 5);
      final row = await refuseOnQuota();
      expect(row!.stateKey, 'uncertainOutcome');
      expect(row.attemptCount, 5);
    });

    test('it cannot override an accepted receipt', () async {
      await seed(firstRecordedAgo: const Duration(hours: 1));
      await repository.saveReceipt(
        WorkflowCommandReceiptRecord()
          ..commandId = command.commandId
          ..aggregateId = command.aggregateId
          ..resultKey = 'maintenance-ticket-acknowledged'
          ..aggregateVersion = 2
          ..resultJson = '{"ticketId":"ticket-fixture"}'
          ..appliedAt = t0,
      );
      final claimed = await repository.claimRetryableCommands(
        now: t0,
        lease: lease,
      );
      // Acceptance is authoritative: the executor settles on the receipt
      // instead of recording this refusal over it.
      await executor(_RefusingGateway(quotaRefusal)).execute(
        command,
        claimedAt: claimed.isEmpty ? null : claimed.single.lastAttemptAt,
      );
      expect(await repository.getReceipt(command.commandId), isNotNull);
    });
  });

  group('the short caller loop', () {
    const policy = WorkflowRetryPolicy();

    test('does not reattempt a quota refusal it cannot honour', () {
      // sync_service retries three times within about six seconds and has no
      // access to the server's retry window. The durable path holds that
      // window, so the short loop must stand aside.
      expect(policy.mayRetryInCallerLoop(quotaRefusal), isFalse);
      expect(
        policy.classify(quotaRefusal),
        WorkflowRetryDisposition.retryUncertain,
        reason: 'still retryable, just not in this loop',
      );
    });

    test('still reattempts ordinary transient failures', () {
      for (final code in <WorkflowErrorCode>[
        WorkflowErrorCode.unavailable,
        WorkflowErrorCode.deadlineExceeded,
        WorkflowErrorCode.aborted,
      ]) {
        expect(
          policy.mayRetryInCallerLoop(WorkflowException(code, 'transient')),
          isTrue,
          reason: code.name,
        );
      }
      expect(
        policy.mayRetryInCallerLoop(
          const WorkflowException(WorkflowErrorCode.invalidArgument, 'no'),
        ),
        isFalse,
      );
    });
  });
}

class _RefusingGateway implements WorkflowCommandGateway {
  _RefusingGateway(this.error);

  final WorkflowException error;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async =>
      throw error;
}
