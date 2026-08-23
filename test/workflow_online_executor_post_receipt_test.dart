import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final command = WorkflowCommand(
    commandId: 'command-accepted-1',
    type: WorkflowCommandType.acknowledgeMaintenanceTicket,
    aggregateId: 'ticket-1',
    expectedVersion: 3,
    payload: const <String, Object?>{'lane': 'mechanical'},
  );
  final receipt = WorkflowCommandReceipt(
    commandId: command.commandId,
    resultKey: 'maintenance-ticket-acknowledged',
    aggregateVersion: 4,
    result: const <String, Object?>{
      'ticketId': 'ticket-1',
      'lane': 'mechanical',
    },
    appliedAt: DateTime.utc(2026, 8, 23, 4),
  );

  test(
    'server receipt remains success when local receipt persistence fails',
    () async {
      final repository = _WorkflowRepository(
        saveReceiptError: StateError('disk'),
      );
      final executor = WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: _WorkflowGateway(receipt: receipt),
        repository: repository,
        now: () => DateTime.utc(2026, 8, 23, 4),
        checkConnectivity:
            () async => const <ConnectivityResult>[ConnectivityResult.wifi],
      );

      await expectLater(executor.execute(command), completion(same(receipt)));
      expect(repository.deleteCalls, 0);
    },
  );

  test('cloud rejection survives a local retry-diagnostic failure', () async {
    const rejection = WorkflowException(
      WorkflowErrorCode.unavailable,
      'The command outcome is uncertain.',
    );
    final executor = WorkflowOnlineExecutor(
      connectivity: Connectivity(),
      gateway: const _WorkflowGateway(error: rejection),
      repository: _WorkflowRepository(
        retryReadError: StateError('local retry store unavailable'),
      ),
      now: () => DateTime.utc(2026, 8, 23, 4),
      checkConnectivity:
          () async => const <ConnectivityResult>[ConnectivityResult.wifi],
    );

    await expectLater(executor.execute(command), throwsA(same(rejection)));
  });

  test(
    'malformed receipt is retained as an uncertain idempotent retry',
    () async {
      final malformed = WorkflowCommandReceipt(
        commandId: 'another-command',
        resultKey: 'maintenance-ticket-acknowledged',
        aggregateVersion: 4,
        result: const <String, Object?>{},
        appliedAt: DateTime.utc(2026, 8, 23, 4),
      );
      final repository = _WorkflowRepository();
      final executor = WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: _ValidatingWorkflowGateway(receipt: malformed),
        repository: repository,
        now: () => DateTime.utc(2026, 8, 23, 4),
        checkConnectivity:
            () async => const <ConnectivityResult>[ConnectivityResult.wifi],
      );

      await expectLater(
        executor.execute(command),
        throwsA(
          isA<WorkflowException>().having(
            (error) => error.code,
            'code',
            WorkflowErrorCode.unavailable,
          ),
        ),
      );
      expect(repository.savedRetry?.commandId, command.commandId);
      expect(repository.savedRetry?.stateKey, 'uncertainOutcome');
    },
  );
}

class _WorkflowGateway implements WorkflowCommandGateway {
  const _WorkflowGateway({this.receipt, this.error});

  final WorkflowCommandReceipt? receipt;
  final WorkflowException? error;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    if (error != null) throw error!;
    return receipt!;
  }
}

class _ValidatingWorkflowGateway implements WorkflowCommandGateway {
  const _ValidatingWorkflowGateway({required this.receipt});

  final WorkflowCommandReceipt receipt;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    if (receipt.commandId != command.commandId) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'The workflow command receipt identity is invalid.',
      );
    }
    return receipt;
  }
}

class _WorkflowRepository implements WorkflowRepository {
  _WorkflowRepository({this.saveReceiptError, this.retryReadError});

  final Object? saveReceiptError;
  final Object? retryReadError;
  int deleteCalls = 0;
  WorkflowCommandRecord? savedRetry;

  @override
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record) async {
    if (saveReceiptError != null) throw saveReceiptError!;
  }

  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) async {
    if (retryReadError != null) throw retryReadError!;
    return null;
  }

  @override
  Future<void> saveRetryCommand(WorkflowCommandRecord record) async {
    savedRetry = record;
  }

  @override
  Future<void> deleteRetryCommand(String commandId) async {
    deleteCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
