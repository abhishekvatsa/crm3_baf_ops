import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/test_support/recording_workflow_repository.dart';

/// On 2026-09-09 Android withheld this app's network for seventy-nine minutes
/// while a healthy Wi-Fi network was connected. Every attempt during that
/// window failed with `unavailable`, and each one spent an attempt from a
/// budget of eight. Eight attempts retire a command to manual review in about
/// thirty-two minutes, so a command could give up entirely while the platform
/// was never going to let it out - and the operator would still believe it was
/// trying.
///
/// A refused request is not evidence about the command. These tests hold the
/// executor to that.
void main() {
  final now = DateTime.utc(2026, 9, 9, 22, 10);

  final command = WorkflowCommand(
    commandId: 'cmd-alarm-1',
    type: WorkflowCommandType.raiseCriticalAlarm,
    aggregateId: 'critical_alarm_1',
    expectedVersion: 0,
    payload: <String, Object?>{'location': 'BASE 205'},
  );

  WorkflowOnlineExecutor executorWith({
    required RecordingWorkflowRepository repository,
    required bool? blocked,
  }) {
    return WorkflowOnlineExecutor(
      connectivity: Connectivity(),
      gateway: _AlwaysUnavailableGateway(),
      repository: repository,
      now: () => now,
      // Connectivity reported a healthy network throughout the incident.
      checkConnectivity: () async => <ConnectivityResult>[
        ConnectivityResult.wifi,
      ],
      isNetworkBlocked: () async => blocked,
    );
  }

  WorkflowCommandRecord retained({
    required int attemptCount,
    String stateKey = 'uncertainOutcome',
  }) {
    return WorkflowCommandRecord()
      ..commandId = command.commandId
      ..aggregateId = command.aggregateId
      ..commandTypeKey = command.type.name
      ..stateKey = stateKey
      ..attemptCount = attemptCount
      ..createdLocallyAt = now.subtract(const Duration(minutes: 20));
  }

  group('while the platform is withholding the network', () {
    test('a retained command is held without spending an attempt', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 3),
      );
      final executor = executorWith(repository: repository, blocked: true);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      final saved = repository.saved.single;
      expect(saved.attemptCount, 3, reason: 'the budget must not be spent');
      expect(saved.stateKey, 'uncertainOutcome');
      expect(saved.lastErrorCode, 'networkBlockedByPlatform');
      expect(
        saved.nextRetryAt,
        now.add(WorkflowOnlineExecutor.platformBlockHold),
      );
    });

    test('the command is never sent', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 1),
      );
      final gateway = _AlwaysUnavailableGateway();
      final executor = WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: gateway,
        repository: repository,
        now: () => now,
        checkConnectivity: () async => <ConnectivityResult>[
          ConnectivityResult.wifi,
        ],
        isNetworkBlocked: () async => true,
      );

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      expect(gateway.callCount, 0);
    });

    test('the operator is told it is paused, not that it failed', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 1),
      );
      final executor = executorWith(repository: repository, blocked: true);

      try {
        await executor.execute(command);
        fail('expected a WorkflowException');
      } on WorkflowException catch (error) {
        expect(error.code, WorkflowErrorCode.unavailable);
        expect(error.message, contains('paused'));
        expect(error.message, contains('will be sent'));
        expect(error.message.toLowerCase(), isNot(contains('failed')));
      }
    });

    test('a first submission is not queued behind the block', () async {
      // This app does not accept lifecycle commands it cannot send. The person
      // raising it must find out now, not discover later that it was waiting.
      final repository = RecordingWorkflowRepository(existing: null);
      final executor = executorWith(repository: repository, blocked: true);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      expect(repository.saved, isEmpty);
    });

    test('a first submission is not described as saved', () async {
      // Nothing was queued, so saying it was is the same class of fault as
      // telling someone a paused sync had failed: the operator cannot tell
      // whether the app is holding their work.
      final repository = RecordingWorkflowRepository(existing: null);
      final executor = executorWith(repository: repository, blocked: true);

      try {
        await executor.execute(command);
        fail('expected a WorkflowException');
      } on WorkflowException catch (error) {
        expect(error.message, contains('not sent'));
        expect(error.message, contains('not been queued'));
        expect(error.message, contains('try again'));
        expect(error.message.toLowerCase(), isNot(contains('is saved')));
      }
    });

    test('a settled command is not described as waiting to be sent', () async {
      for (final state in <String>['rejected', 'manualReview']) {
        final repository = RecordingWorkflowRepository(
          existing: retained(attemptCount: 8, stateKey: state),
        );
        final executor = executorWith(repository: repository, blocked: true);

        try {
          await executor.execute(command);
          fail('expected a WorkflowException');
        } on WorkflowException catch (error) {
          expect(error.message, contains('needs review'));
          expect(error.message.toLowerCase(), isNot(contains('will be sent')));
        }
      }
    });

    test('a settled command is not resurrected by a hold', () async {
      for (final state in <String>['rejected', 'manualReview']) {
        final repository = RecordingWorkflowRepository(
          existing: retained(attemptCount: 8, stateKey: state),
        );
        final executor = executorWith(repository: repository, blocked: true);

        await expectLater(
          () => executor.execute(command),
          throwsA(isA<WorkflowException>()),
        );

        expect(repository.saved, isEmpty, reason: '$state must stay $state');
      }
    });
  });

  group('a late failure cannot downgrade established acceptance', () {
    WorkflowCommandReceiptRecord receiptFor(String commandId) =>
        WorkflowCommandReceiptRecord()
          ..commandId = commandId
          ..aggregateId = command.aggregateId
          ..resultKey = 'applied'
          ..aggregateVersion = 1
          ..appliedAt = now;

    test('the accepted outcome is returned, not the stale failure', () async {
      // B already settled and removed the row; A arrives late with a
      // transport error. The command did land, so reporting a failure would
      // tell the operator their work was lost when it was not.
      final repository = RecordingWorkflowRepository(
        existing: null,
        acceptedReceipt: receiptFor(command.commandId),
      );
      final executor = executorWith(repository: repository, blocked: false);

      final receipt = await executor.execute(command);

      expect(receipt.commandId, command.commandId);
      expect(receipt.resultKey, 'applied');
      expect(
        repository.saved,
        isEmpty,
        reason: 'an accepted command must not reappear as unresolved',
      );
    });

    test('an existing row is not downgraded after acceptance either', () async {
      // Acceptance was recorded but the row removal did not complete. The
      // receipt still outranks a late transport failure.
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 2),
        acceptedReceipt: receiptFor(command.commandId),
      );
      final executor = executorWith(repository: repository, blocked: false);

      final receipt = await executor.execute(command);

      expect(receipt.commandId, command.commandId);
      expect(repository.saved, isEmpty);
    });

    test('acceptance landing mid-decision still wins', () async {
      // The interleaving the earlier pre-read could not stop: the check finds
      // no receipt, another caller then commits acceptance and clears the
      // row, and the late write recreates uncertainty. The guarded transition
      // reads its evidence in the same step that writes, so the acceptance is
      // either already visible or lands after - never in between.
      final repository = RecordingWorkflowRepository(existing: null);
      repository.beforeTransition = () async {
        await repository.settleAccepted(receiptFor(command.commandId));
      };
      final executor = executorWith(repository: repository, blocked: false);

      final receipt = await executor.execute(command);

      expect(receipt.commandId, command.commandId);
      expect(
        repository.saved,
        isEmpty,
        reason: 'no uncertain row may be written once acceptance is committed',
      );
    });

    test('a hold cannot return accepted work to waiting', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 2),
        acceptedReceipt: receiptFor(command.commandId),
      );
      final executor = executorWith(repository: repository, blocked: true);

      try {
        await executor.execute(command);
      } on WorkflowException catch (error) {
        // The block short-circuits before dispatch, so no receipt is returned
        // here; what matters is that the hold wrote nothing and did not
        // describe accepted work as waiting.
        expect(error.message, isNot(contains('will be sent')));
      }

      expect(repository.saved, isEmpty);
    });

    test('a receipt for another command does not suppress the failure', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 2),
        acceptedReceipt: receiptFor('some-other-command'),
      );
      final executor = executorWith(repository: repository, blocked: false);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      expect(repository.saved.single.attemptCount, 3);
    });
  });

  group('when the platform is not withholding the network', () {
    test('an ordinary failure still spends an attempt', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 3),
      );
      final executor = executorWith(repository: repository, blocked: false);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      // A real server failure is evidence about the command, so the budget
      // exists precisely to bound it.
      expect(repository.saved.single.attemptCount, 4);
      expect(repository.saved.single.lastErrorCode, isNot('networkBlockedByPlatform'));
    });

    test('an unknown platform answer is not treated as a block', () async {
      // Below API 29 there is no per-UID signal. Holding on a guess would
      // stall commands that could have been sent.
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 3),
      );
      final executor = executorWith(repository: repository, blocked: null);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      expect(repository.saved.single.attemptCount, 4);
    });

    test('the eight-attempt budget still retires a command', () async {
      final repository = RecordingWorkflowRepository(
        existing: retained(attemptCount: 7),
      );
      final executor = executorWith(repository: repository, blocked: false);

      await expectLater(
        () => executor.execute(command),
        throwsA(isA<WorkflowException>()),
      );

      expect(repository.saved.single.stateKey, 'manualReview');
      expect(repository.saved.single.nextRetryAt, isNull);
    });
  });
}

class _AlwaysUnavailableGateway implements WorkflowCommandGateway {
  _AlwaysUnavailableGateway();

  int callCount = 0;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    callCount += 1;
    throw const WorkflowException(
      WorkflowErrorCode.unavailable,
      'unreachable',
    );
  }
}
