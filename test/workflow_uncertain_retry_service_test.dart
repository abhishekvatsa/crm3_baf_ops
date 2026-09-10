import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
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

      final applied = await serviceWith(gateway).retryDueCommands();

      expect(applied, 0);
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
      // The manual-review write goes through the receipt-aware transition, so
      // a command settled by another caller cannot reappear as outstanding.
      await seedDue(commandId: 'cmd-bad', payloadJson: 'not json');
      await repository.settleAccepted(
        WorkflowCommandReceiptRecord()
          ..commandId = 'cmd-bad'
          ..aggregateId = 'ticket-base-205'
          ..resultKey = 'maintenance-ticket-acknowledged'
          ..aggregateVersion = 5
          ..appliedAt = now,
      );

      await serviceWith(_Gateway.accepting()).retryDueCommands();

      expect(await repository.getRetryCommand('cmd-bad'), isNull);
      expect(await repository.getReceipt('cmd-bad'), isNotNull);
    });
  });

  group('a readable payload', () {
    test('is dispatched and settled on acceptance', () async {
      await seedDue(
        commandId: 'cmd-good',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final gateway = _Gateway.accepting();

      final applied = await serviceWith(gateway).retryDueCommands();

      expect(applied, 1);
      expect(gateway.calls, 1);
      expect(await repository.getRetryCommand('cmd-good'), isNull);
      expect(await repository.getReceipt('cmd-good'), isNotNull);
    });

    test('a transport failure is not mistaken for a bad payload', () async {
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
  _Gateway.accepting() : failure = null;
  _Gateway.failing(this.failure);

  final WorkflowException? failure;
  int calls = 0;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    calls += 1;
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
