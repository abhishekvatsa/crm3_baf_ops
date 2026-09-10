import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_uncertain_retry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

/// The governed A-05 surface `workflow-uncertain-retry` declares this file as
/// its regression, with the disposition "fail closed and retain retry row" and
/// a re-arm condition of "malformed retry payload is discarded or executed".
/// The file did not exist. These tests supply it, against the real Isar
/// repository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Isar isar;
  late IsarWorkflowRepository repository;
  late Directory directory;

  final now = DateTime.utc(2026, 9, 10, 8, 0);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('uncertain_retry_');
    isar = await Isar.open(
      [WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema],
      directory: directory.path,
      name: 'uncertain_retry_test',
      inspector: false,
    );
    repository = IsarWorkflowRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<void> seedDue({
    required String commandId,
    required String payloadJson,
    String commandTypeKey = 'acknowledgeMaintenanceTicket',
  }) async {
    await repository.saveRetryCommand(
      WorkflowCommandRecord()
        ..commandId = commandId
        ..aggregateId = 'ticket-base-205'
        ..commandTypeKey = commandTypeKey
        ..payloadJson = payloadJson
        ..stateKey = 'uncertainOutcome'
        ..nextRetryAt = now.subtract(const Duration(minutes: 1))
        ..createdLocallyAt = now.subtract(const Duration(hours: 1)),
    );
  }

  WorkflowUncertainRetryService serviceWith(_Gateway gateway) {
    return WorkflowUncertainRetryService(
      repository: repository,
      executor: WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: gateway,
        repository: repository,
        now: () => now,
        checkConnectivity:
            () async => <ConnectivityResult>[ConnectivityResult.wifi],
        isNetworkBlocked: () async => false,
      ),
      now: () => now,
    );
  }

  group('a malformed retry payload', () {
    test('is retained for review, never discarded or executed', () async {
      await seedDue(commandId: 'cmd-bad', payloadJson: 'not json');
      final gateway = _Gateway.accepting();

      final summary = await serviceWith(gateway).retryDueCommands();

      expect(summary.applied, isEmpty);
      expect(summary.manualReview, <String>['cmd-bad']);
      expect(gateway.calls, 0, reason: 'unreadable intent must not be sent');

      final row = await repository.getRetryCommand('cmd-bad');
      expect(row, isNotNull, reason: 'the row must be retained, not discarded');
      expect(row!.stateKey, 'manualReview');
      expect(row.nextRetryAt, isNull);
      expect(row.lastErrorCode, 'malformedLocalCommand');
    });

    test('an unknown command type is treated the same way', () async {
      await seedDue(
        commandId: 'cmd-unknown-type',
        payloadJson: '{}',
        commandTypeKey: 'noSuchCommandType',
      );
      final gateway = _Gateway.accepting();

      await serviceWith(gateway).retryDueCommands();

      expect(gateway.calls, 0);
      final row = await repository.getRetryCommand('cmd-unknown-type');
      expect(row!.stateKey, 'manualReview');
    });

    test('does not resurrect work the server already accepted', () async {
      // The ordering that matters: the service must already hold the malformed
      // row when acceptance lands, so its terminal write actually runs against
      // a settled command. Settling first would delete the row before the
      // service ever claimed it, and the test would pass even if the write
      // went back to bypassing the receipt-aware transition.
      await seedDue(commandId: 'cmd-bad', payloadJson: 'not json');
      final settling = _SettleOnClaimRepository(
        repository,
        onClaimed: (commandId) => repository.settleAccepted(
          WorkflowCommandReceiptRecord()
            ..commandId = commandId
            ..aggregateId = 'ticket-base-205'
            ..resultKey = 'maintenance-ticket-acknowledged'
            ..aggregateVersion = 5
            ..appliedAt = now,
        ),
      );

      final summary = await WorkflowUncertainRetryService(
        repository: settling,
        executor: WorkflowOnlineExecutor(
          connectivity: Connectivity(),
          gateway: _Gateway.accepting(),
          repository: settling,
          now: () => now,
          checkConnectivity:
              () async => <ConnectivityResult>[ConnectivityResult.wifi],
          isNetworkBlocked: () async => false,
        ),
        now: () => now,
      ).retryDueCommands();

      expect(await repository.getRetryCommand('cmd-bad'), isNull);
      expect(await repository.getReceipt('cmd-bad'), isNotNull);
      expect(summary.manualReview, isEmpty);
    });
  });

  group('a readable payload', () {
    test('is dispatched and settled on acceptance', () async {
      await seedDue(
        commandId: 'cmd-good',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final gateway = _Gateway.accepting();

      final summary = await serviceWith(gateway).retryDueCommands();

      expect(summary.applied, <String>['cmd-good']);
      expect(gateway.calls, 1);
      expect(await repository.getRetryCommand('cmd-good'), isNull);
      expect(await repository.getReceipt('cmd-good'), isNotNull);
    });

    test('an execution StateError is not labelled a malformed payload', () async {
      // The old catch covered decoding and sending together, so a StateError
      // raised inside the send retired a perfectly readable command to manual
      // review. A WorkflowException would never have shown that.
      await seedDue(
        commandId: 'cmd-good',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final gateway = _Gateway.throwing(StateError('gateway fault'));

      final summary = await serviceWith(gateway).retryDueCommands();

      final row = await repository.getRetryCommand('cmd-good');
      expect(row!.stateKey, isNot('manualReview'));
      expect(row.lastErrorCode, isNot('malformedLocalCommand'));
      // And the fault is reported rather than reduced to "nothing applied".
      expect(summary.failedVerification, <String>['cmd-good']);
      expect(summary.needsAttention, isTrue);
    });

    test('one unresolvable command does not block the ones behind it', () async {
      // The run used to release the oldest command, immediately reclaim it,
      // see it again and stop - so every command behind it went unattempted.
      await seedDue(
        commandId: 'cmd-stuck',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      await seedDue(
        commandId: 'cmd-behind',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'ELECTRICAL'}),
      );
      final gateway = _Gateway.throwingFor(
        'cmd-stuck',
        StateError('gateway fault'),
      );

      final summary = await serviceWith(gateway).retryDueCommands();

      expect(summary.failedVerification, contains('cmd-stuck'));
      expect(
        summary.applied,
        contains('cmd-behind'),
        reason: 'the queue must keep moving past one bad command',
      );
    });

    test('a terminal rejection is not reported as still retrying', () async {
      // permissionDenied is classified as a rejection, so the command will
      // never progress. Calling it deferred tells a caller work is still
      // coming that never is.
      await seedDue(
        commandId: 'cmd-refused',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final gateway = _Gateway.failing(
        const WorkflowException(
          WorkflowErrorCode.permissionDenied,
          'not permitted',
        ),
      );

      final summary = await serviceWith(gateway).retryDueCommands();

      expect(summary.rejected, <String>['cmd-refused']);
      expect(summary.deferred, isEmpty);
      expect(summary.needsAttention, isTrue);
      expect((await repository.getRetryCommand('cmd-refused'))!.stateKey,
          'rejected');
    });

    test('a transport failure is deferred, not mistaken for a bad payload', () async {
      // The decode and the send are caught separately. Catching both together
      // let an error raised inside the send retire a perfectly readable
      // command to manual review.
      await seedDue(
        commandId: 'cmd-good',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final gateway = _Gateway.failing(
        const WorkflowException(WorkflowErrorCode.unavailable, 'unreachable'),
      );

      await serviceWith(gateway).retryDueCommands();

      final row = await repository.getRetryCommand('cmd-good');
      expect(row!.stateKey, 'uncertainOutcome');
      expect(row.lastErrorCode, isNot('malformedLocalCommand'));
      expect(row.nextRetryAt, isNotNull, reason: 'it remains retryable');
    });
  });
}

class _Gateway implements WorkflowCommandGateway {
  _Gateway.accepting() : failure = null, fault = null, faultFor = null;
  _Gateway.failing(this.failure) : fault = null, faultFor = null;
  _Gateway.throwing(this.fault) : failure = null, faultFor = null;
  _Gateway.throwingFor(this.faultFor, this.fault) : failure = null;

  final WorkflowException? failure;

  /// A non-WorkflowException raised inside the send. This is the shape the old
  /// combined catch misread as a malformed stored payload.
  final Object? fault;

  /// Restricts [fault] to one command, so a second command can still succeed.
  final String? faultFor;

  int calls = 0;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    calls += 1;
    final raised = fault;
    if (raised != null &&
        (faultFor == null || faultFor == command.commandId)) {
      throw raised;
    }
    final error = failure;
    if (error != null) throw error;
    return WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-acknowledged',
      aggregateVersion: command.expectedVersion + 1,
      result: const <String, Object?>{'ticketId': 'ticket-base-205'},
      appliedAt: DateTime.utc(2026, 9, 10, 8, 0),
    );
  }
}

/// Lets acceptance land while the service already holds a claim.
///
/// The dangerous ordering cannot be arranged from outside: the service claims
/// and then writes, so a test that settles first simply deletes the row before
/// the run begins. This wrapper settles at the moment of the claim instead, so
/// the terminal write really does run against a settled command.
class _SettleOnClaimRepository implements WorkflowRepository {
  _SettleOnClaimRepository(this._inner, {required this.onClaimed});

  final WorkflowRepository _inner;
  final Future<void> Function(String commandId) onClaimed;
  final Set<String> _fired = <String>{};

  @override
  Future<List<WorkflowCommandRecord>> claimRetryableCommands({
    required DateTime now,
    required Duration lease,
    int limit = 1,
    Set<String> exclude = const <String>{},
  }) async {
    final claimed = await _inner.claimRetryableCommands(
      now: now,
      lease: lease,
      limit: limit,
      exclude: exclude,
    );
    for (final row in claimed) {
      if (_fired.add(row.commandId)) await onClaimed(row.commandId);
    }
    return claimed;
  }

  @override
  Future<void> releaseClaim(
    String commandId, {
    required DateTime claimedAt,
    DateTime? nextRetryAt,
  }) => _inner.releaseClaim(
    commandId,
    claimedAt: claimedAt,
    nextRetryAt: nextRetryAt,
  );

  @override
  Future<WorkflowRetryTransition> applyRetryTransitionUnlessAccepted({
    required String commandId,
    required WorkflowCommandRecord? Function(WorkflowCommandRecord? current)
    build,
  }) => _inner.applyRetryTransitionUnlessAccepted(
    commandId: commandId,
    build: build,
  );

  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) =>
      _inner.getRetryCommand(commandId);

  @override
  Future<void> saveRetryCommand(WorkflowCommandRecord record) =>
      _inner.saveRetryCommand(record);

  @override
  Future<void> deleteRetryCommand(String commandId) =>
      _inner.deleteRetryCommand(commandId);

  @override
  Future<WorkflowCommandReceiptRecord?> getReceipt(String commandId) =>
      _inner.getReceipt(commandId);

  @override
  Future<void> settleAccepted(WorkflowCommandReceiptRecord receipt) =>
      _inner.settleAccepted(receipt);

  @override
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record) =>
      _inner.saveReceipt(record);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
