import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_outbox_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

// Restore the project's existing native test support omitted from the review
// snapshot. This is the same initializer used by its current Isar tests.
import '../../tool/test_support/test_isar_core.dart';

// Isar returns DateTime values in local time. Dart's DateTime.== requires a
// matching isUtc flag as well as the same instant, so these comparisons
// normalise before asserting rather than depending on the runner's zone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late IsarWorkflowRepository repository;
  final t0 = DateTime.utc(2026, 9, 11, 8);
  const lease = Duration(minutes: 5);
  final command = WorkflowCommand(commandId: 'claim-fixture',
    type: WorkflowCommandType.acknowledgeMaintenanceTicket,
    aggregateId: 'ticket-fixture', expectedVersion: 1,
    payload: const <String, Object?>{'laneKey': 'mech'});

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('claim_outcome_audit_');
    database = await Isar.open([
      WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema,
    ], directory: directory.path, name: 'claim_outcome_audit', inspector: false);
    repository = IsarWorkflowRepository(database);
    await repository.saveRetryCommand(WorkflowCommandRecord()
      ..commandId = command.commandId ..aggregateId = command.aggregateId
      ..commandTypeKey = command.type.name ..expectedVersion = command.expectedVersion
      ..payloadJson = '{"laneKey":"mech"}' ..stateKey = 'uncertainOutcome'
      ..attemptCount = 7 ..createdLocallyAt = t0.subtract(const Duration(hours: 1))
      ..nextRetryAt = t0.subtract(const Duration(minutes: 1)));
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  WorkflowOnlineExecutor executor(_BarrierGateway gateway) => WorkflowOnlineExecutor(
    connectivity: Connectivity(), gateway: gateway, repository: repository,
    now: () => t0, checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.wifi],
    isNetworkBlocked: () async => false,
  );

  test('late failure cannot replace the second claimant state', () async {
    final first = (await repository.claimRetryableCommands(now: t0, lease: lease)).single;
    final gateway = _BarrierGateway();
    final result = executor(gateway).execute(command, claimedAt: first.lastAttemptAt);
    final observedFailure = expectLater(result, throwsA(isA<WorkflowException>()));
    await gateway.entered.future;
    final second = (await repository.claimRetryableCommands(
      now: t0.add(const Duration(minutes: 6)), lease: lease)).single;
    gateway.response.completeError(const WorkflowException(WorkflowErrorCode.unavailable, 'late transport failure'));
    await observedFailure;
    final retained = await repository.getRetryCommand(command.commandId);
    expect(retained!.stateKey, 'sending');
    expect(retained.lastAttemptAt!.toUtc(), second.lastAttemptAt!.toUtc());
    expect(retained.attemptCount, 7);
  });

  test('late authoritative acceptance is retained despite a newer claim', () async {
    final first = (await repository.claimRetryableCommands(now: t0, lease: lease)).single;
    final gateway = _BarrierGateway();
    final result = executor(gateway).execute(command, claimedAt: first.lastAttemptAt);
    await gateway.entered.future;
    await repository.claimRetryableCommands(now: t0.add(const Duration(minutes: 6)), lease: lease);
    gateway.response.complete(WorkflowCommandReceipt(commandId: command.commandId,
      resultKey: 'maintenance-ticket-acknowledged', aggregateVersion: 2,
      result: <String, Object?>{'ticketId': command.aggregateId, 'auditId': 'audit-fixture', 'lane': 'mech'},
      appliedAt: t0));
    expect((await result).result['auditId'], 'audit-fixture');
    expect(await repository.getRetryCommand(command.commandId), isNull);
    expect(await repository.getReceipt(command.commandId), isNotNull);
  });

  test('quota refusal preserves attempt budget and server retry window', () async {
    final first = (await repository.claimRetryableCommands(now: t0, lease: lease)).single;
    final gateway = _BarrierGateway();
    final result = executor(gateway).execute(command, claimedAt: first.lastAttemptAt);
    final observedFailure = expectLater(result, throwsA(isA<WorkflowException>()));
    await gateway.entered.future;
    gateway.response.completeError(const WorkflowException(WorkflowErrorCode.resourceExhausted,
      'Quota temporarily exhausted.', details: <String, Object?>{'retryAfterSeconds': 1200}));
    await observedFailure;
    final retained = await repository.getRetryCommand(command.commandId);
    expect(retained!.stateKey, 'uncertainOutcome');
    expect(retained.attemptCount, 7);
    expect(retained.nextRetryAt!.toUtc(), t0.add(const Duration(seconds: 1200)));
    expect(retained.commandId, command.commandId);
  });

  test('a request refused on quota for too long stops waiting for a human', () async {
    // The attempt-budget exemption keeps a quota-refused request retryable.
    // Without an elapsed-time bound a server that keeps refusing would defer
    // the same request forever and it would never reach anyone who could act.
    await repository.saveRetryCommand(WorkflowCommandRecord()
      ..commandId = command.commandId ..aggregateId = command.aggregateId
      ..commandTypeKey = command.type.name
      ..expectedVersion = command.expectedVersion
      ..payloadJson = '{"laneKey":"mech"}' ..stateKey = 'uncertainOutcome'
      ..attemptCount = 7
      ..createdLocallyAt =
          t0.subtract(WorkflowRetryPolicy.maxQuotaDeferral).subtract(
            const Duration(minutes: 1))
      ..nextRetryAt = t0.subtract(const Duration(minutes: 1)));
    final first = (await repository.claimRetryableCommands(
      now: t0, lease: lease)).single;
    final gateway = _BarrierGateway();
    final result = executor(gateway).execute(command, claimedAt: first.lastAttemptAt);
    final observedFailure = expectLater(result, throwsA(isA<WorkflowException>()));
    await gateway.entered.future;
    gateway.response.completeError(const WorkflowException(
      WorkflowErrorCode.resourceExhausted, 'Quota temporarily exhausted.',
      details: <String, Object?>{'retryAfterSeconds': 1200}));
    await observedFailure;
    final retained = await repository.getRetryCommand(command.commandId);
    // Needs a person, but the work is not discarded and keeps its identity.
    expect(retained!.stateKey, 'manualReview');
    expect(retained.nextRetryAt, isNull);
    expect(retained.commandId, command.commandId);
    expect(retained.attemptCount, 7);
  });
}

class _BarrierGateway implements WorkflowCommandGateway {
  final entered = Completer<void>();
  final response = Completer<WorkflowCommandReceipt>();
  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    entered.complete();
    return response.future;
  }
}
