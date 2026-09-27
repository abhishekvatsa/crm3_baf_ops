import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
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

  WorkflowUncertainRetryService serviceWith(
    WorkflowCommandGateway gateway, {
    WorkflowRepository? retryRepository,
    String? Function()? originActorUid,
    DateTime Function()? clock,
  }) {
    final store = retryRepository ?? repository;
    return WorkflowUncertainRetryService(
      repository: store,
      executor: WorkflowOnlineExecutor(
        connectivity: Connectivity(),
        gateway: gateway,
        repository: store,
        now: clock ?? () => now,
        checkConnectivity: () async => <ConnectivityResult>[
          ConnectivityResult.wifi,
        ],
        isNetworkBlocked: () async => false,
        originActorUid: originActorUid,
      ),
      now: clock ?? () => now,
    );
  }

  group('a guarded sync run', () {
    late bool current;
    late SyncRunGuard guard;

    setUp(() {
      current = true;
      guard = SyncRunGuard(() {
        if (!current) {
          throw const SyncRunAborted('account-or-authority-changed');
        }
      });
    });

    Future<void> seedPair() async {
      await seedDue(
        commandId: 'cmd-first',
        payloadJson: '{"lane":"MECHANICAL"}',
      );
      await seedDue(
        commandId: 'cmd-next',
        payloadJson: '{"lane":"ELECTRICAL"}',
      );
    }

    Future<void> expectNextUntouched() async {
      final next = (await repository.getRetryCommand('cmd-next'))!;
      expect(next.stateKey, 'uncertainOutcome');
      expect(next.lastAttemptAt, isNull);
      expect(next.attemptCount, 0);
    }

    test('an invalid session never takes the first claim', () async {
      await seedPair();
      current = false;
      final gateway = _Gateway.accepting();
      await expectLater(
        serviceWith(gateway).retryDueCommands(runGuard: guard),
        throwsA(isA<SyncRunAborted>()),
      );
      expect(gateway.calls, 0);
      expect(
        (await repository.getRetryCommand('cmd-first'))!.lastAttemptAt,
        isNull,
      );
      await expectNextUntouched();
    });

    test(
      'an interrupted claim releases only its lease without changing intent',
      () async {
        await seedPair();
        final before = (await repository.getRetryCommand('cmd-first'))!;
        final claims = _SettleOnClaimRepository(
          repository,
          onClaimed: (_) async {
            current = false;
          },
        );
        final gateway = _Gateway.accepting();
        await expectLater(
          serviceWith(
            gateway,
            retryRepository: claims,
          ).retryDueCommands(runGuard: guard),
          throwsA(isA<SyncRunAborted>()),
        );
        final after = (await repository.getRetryCommand('cmd-first'))!;
        expect(after.stateKey, 'uncertainOutcome');
        expect(after.lastAttemptAt?.toUtc(), now);
        expect(after.payloadJson, before.payloadJson);
        expect(after.nextRetryAt, before.nextRetryAt);
        expect(after.attemptCount, before.attemptCount);
        expect(gateway.calls, 0);
        await expectNextUntouched();
      },
    );

    test('abort cleanup cannot release a newer claimant', () async {
      await seedPair();
      final newerClaim = now.add(const Duration(minutes: 6));
      final claims = _SettleOnClaimRepository(
        repository,
        onClaimed: (id) async {
          final newer = (await repository.getRetryCommand(id))!
            ..lastAttemptAt = newerClaim;
          await repository.saveRetryCommand(newer);
          current = false;
        },
      );
      await expectLater(
        serviceWith(
          _Gateway.accepting(),
          retryRepository: claims,
        ).retryDueCommands(runGuard: guard),
        throwsA(isA<SyncRunAborted>()),
      );
      final after = (await repository.getRetryCommand('cmd-first'))!;
      expect(after.stateKey, 'sending');
      expect(after.lastAttemptAt?.toUtc(), newerClaim);
      await expectNextUntouched();
    });

    test(
      'abort cleanup leaves an accepted receipt and its evidence intact',
      () async {
        await seedPair();
        final claims = _SettleOnClaimRepository(
          repository,
          onClaimed: (id) async {
            // A receipt may arrive before its retry row is reconciled. Cleanup
            // must consult the receipt atomically, not just the sending lease.
            await repository.saveReceipt(
              WorkflowCommandReceiptRecord()
                ..commandId = id
                ..aggregateId = 'ticket-base-205'
                ..resultKey = 'maintenance-ticket-acknowledged'
                ..aggregateVersion = 5
                ..appliedAt = now,
            );
            current = false;
          },
        );
        await expectLater(
          serviceWith(
            _Gateway.accepting(),
            retryRepository: claims,
          ).retryDueCommands(runGuard: guard),
          throwsA(isA<SyncRunAborted>()),
        );
        expect(await repository.getReceipt('cmd-first'), isNotNull);
        expect(
          (await repository.getRetryCommand('cmd-first'))!.stateKey,
          'sending',
        );
        await expectNextUntouched();
      },
    );

    test(
      'lost authentication aborts instead of becoming a retry summary',
      () async {
        await seedPair();
        final gateway = _Gateway.failing(
          const WorkflowException(
            WorkflowErrorCode.unauthenticated,
            'session ended',
          ),
        );
        await expectLater(
          serviceWith(gateway).retryDueCommands(runGuard: guard),
          throwsA(
            isA<SyncRunAborted>().having(
              (e) => e.reason,
              'reason',
              'unauthenticated',
            ),
          ),
        );
        expect(gateway.calls, 1);
        final first = (await repository.getRetryCommand('cmd-first'))!;
        expect(first.stateKey, isNot('sending'));
        expect(first.payloadJson, '{"lane":"MECHANICAL"}');
        await expectNextUntouched();
      },
    );

    test(
      'unavailable local storage aborts and releases the exact owned claim',
      () async {
        await seedPair();
        final fault = IsarError('local store unavailable');
        final gateway = _Gateway.throwing(fault);
        await expectLater(
          serviceWith(gateway).retryDueCommands(runGuard: guard),
          throwsA(same(fault)),
        );
        expect(gateway.calls, 1);
        expect(
          (await repository.getRetryCommand('cmd-first'))!.stateKey,
          'uncertainOutcome',
        );
        await expectNextUntouched();
      },
    );

    test(
      'a session change during execution preserves acceptance but stops the run',
      () async {
        await seedPair();
        final gateway = _Gateway.accepting()
          ..beforeResult = () async {
            current = false;
          };
        await expectLater(
          serviceWith(gateway).retryDueCommands(runGuard: guard),
          throwsA(isA<SyncRunAborted>()),
        );
        expect(gateway.calls, 1);
        expect(await repository.getReceipt('cmd-first'), isNotNull);
        expect(await repository.getRetryCommand('cmd-first'), isNull);
        await expectNextUntouched();
      },
    );

    test('a record-specific fault still allows the next command', () async {
      await seedPair();
      final gateway = _Gateway.throwingFor(
        'cmd-first',
        StateError('record fault'),
      );
      final summary = await serviceWith(
        gateway,
      ).retryDueCommands(runGuard: guard);
      expect(summary.failedVerification, ['cmd-first']);
      expect(summary.applied, ['cmd-next']);
      expect(gateway.calls, 2);
    });
  });

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
          checkConnectivity: () async => <ConnectivityResult>[
            ConnectivityResult.wifi,
          ],
          isNetworkBlocked: () async => false,
        ),
        now: () => now,
      ).retryDueCommands();

      expect(await repository.getRetryCommand('cmd-bad'), isNull);
      expect(await repository.getReceipt('cmd-bad'), isNotNull);
      expect(summary.manualReview, isEmpty);
    });
  });

  group('releasing an abandoned first-send claim', () {
    final command = WorkflowCommand(
      commandId: 'cmd-abandoned',
      type: WorkflowCommandType.acknowledgeMaintenanceTicket,
      aggregateId: 'ticket-base-205',
      expectedVersion: 4,
      payload: const {'lane': 'MECHANICAL'},
    );
    final originalPayload = jsonEncode({
      '__workflowOriginBoundV1': 'actor-a',
      'payload': command.payload,
    });

    Future<void> seedAbandoned({DateTime? nextRetryAt}) =>
        repository.saveRetryCommand(
          WorkflowCommandRecord()
            ..commandId = command.commandId
            ..aggregateId = command.aggregateId
            ..commandTypeKey = command.type.name
            ..expectedVersion = command.expectedVersion
            ..payloadJson = originalPayload
            ..stateKey = 'sending'
            ..lastAttemptAt = now.subtract(const Duration(minutes: 6))
            ..nextRetryAt = nextRetryAt
            ..createdLocallyAt = now.subtract(const Duration(hours: 1)),
        );

    void expectOriginalIntent(WorkflowCommandRecord row) {
      expect(row.commandId, command.commandId);
      expect(row.aggregateId, command.aggregateId);
      expect(row.commandTypeKey, command.type.name);
      expect(row.expectedVersion, command.expectedVersion);
      expect(row.payloadJson, originalPayload);
      expect(row.attemptCount, 0);
      expect(
        row.createdLocallyAt.toUtc(),
        now.subtract(const Duration(hours: 1)),
      );
      expect(row.lastErrorCode, isNull);
      expect(row.lastErrorMessage, isNull);
    }

    test(
      'session abort remains retryable after restart, never sends under B, and replays exactly for A',
      () async {
        await seedAbandoned();
        var current = true;
        var actorUid = 'actor-a';
        var clock = now;
        final gateway = _OriginGateway();
        final interrupted = _SettleOnClaimRepository(
          repository,
          onClaimed: (_) async {
            current = false;
            actorUid = 'actor-b';
          },
        );
        await expectLater(
          serviceWith(
            gateway,
            retryRepository: interrupted,
            originActorUid: () => actorUid,
            clock: () => clock,
          ).retryDueCommands(
            runGuard: SyncRunGuard(() {
              if (!current) {
                throw const SyncRunAborted('account-or-authority-changed');
              }
            }),
          ),
          throwsA(isA<SyncRunAborted>()),
        );
        final released = (await repository.getRetryCommand(command.commandId))!;
        expect(released.stateKey, 'uncertainOutcome');
        expect(released.lastAttemptAt?.toUtc(), now);
        expect(released.nextRetryAt?.toUtc(), now);
        expectOriginalIntent(released);
        expect(gateway.envelopes, isEmpty);
        expect(
          (await repository.getRetryableCommands(
            now,
          )).map((row) => row.commandId),
          [command.commandId],
        );

        // Recreate the native store and service with the replacement account.
        await isar.close();
        isar = await Isar.open(
          [WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema],
          directory: directory.path,
          name: 'uncertain_retry_test',
          inspector: false,
        );
        repository = IsarWorkflowRepository(isar);
        final blocked = await serviceWith(
          gateway,
          originActorUid: () => actorUid,
          clock: () => clock,
        ).retryDueCommands(runGuard: SyncRunGuard(() {}));
        expect(blocked.deferred, [command.commandId]);
        expect(blocked.applied, isEmpty);
        expect(gateway.envelopes, isEmpty);
        final held = (await repository.getRetryCommand(command.commandId))!;
        expectOriginalIntent(held);
        expect(
          held.nextRetryAt?.toUtc(),
          now.add(WorkflowOnlineExecutor.platformBlockHold),
        );
        expect(await repository.getReceipt(command.commandId), isNull);

        actorUid = 'actor-a';
        clock = held.nextRetryAt!.toUtc();
        final resumed = await serviceWith(
          gateway,
          originActorUid: () => actorUid,
          clock: () => clock,
        ).retryDueCommands(runGuard: SyncRunGuard(() {}));
        expect(resumed.applied, [command.commandId]);
        expect(gateway.envelopes, [
          jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'actor-a',
            'command': command.toMap(),
          }),
        ]);
        expect(await repository.getRetryCommand(command.commandId), isNull);
        expect(await repository.getReceipt(command.commandId), isNotNull);
      },
    );

    test('aborted abandoned claim preserves an existing future hold', () async {
      final hold = now.add(const Duration(hours: 1));
      await seedAbandoned(nextRetryAt: hold);
      var current = true;
      final gateway = _Gateway.accepting();
      await expectLater(
        serviceWith(
          gateway,
          retryRepository: _SettleOnClaimRepository(
            repository,
            onClaimed: (_) async => current = false,
          ),
        ).retryDueCommands(
          runGuard: SyncRunGuard(() {
            if (!current) {
              throw const SyncRunAborted('disposed');
            }
          }),
        ),
        throwsA(isA<SyncRunAborted>()),
      );
      final released = (await repository.getRetryCommand(command.commandId))!;
      expect(released.nextRetryAt?.toUtc(), hold);
      expectOriginalIntent(released);
      expect(gateway.calls, 0);
      expect(await repository.getRetryableCommands(now), isEmpty);
      expect(
        (await repository.getRetryableCommands(hold)).single.commandId,
        command.commandId,
      );
    });

    for (final mode in [
      'no prior schedule',
      'existing future hold',
      'explicit future hold',
    ]) {
      test('ordinary release preserves eligibility and $mode', () async {
        final hold = now.add(const Duration(hours: 1));
        await seedAbandoned(
          nextRetryAt: mode == 'existing future hold' ? hold : null,
        );
        final claimed = (await repository.claimRetryableCommands(
          now: now,
          lease: WorkflowUncertainRetryService.claimLease,
        )).single;
        await repository.releaseClaim(
          command.commandId,
          claimedAt: claimed.lastAttemptAt!,
          nextRetryAt: mode == 'explicit future hold' ? hold : null,
        );
        final released = (await repository.getRetryCommand(command.commandId))!;
        final due = mode == 'no prior schedule' ? now : hold;
        expect(released.stateKey, 'uncertainOutcome');
        expect(released.nextRetryAt?.toUtc(), due);
        expectOriginalIntent(released);
        expect(
          (await repository.getRetryableCommands(due)).single.commandId,
          command.commandId,
        );
        if (due.isAfter(now)) {
          expect(await repository.getRetryableCommands(now), isEmpty);
        }
        expect(
          (await repository.claimRetryableCommands(
            now: due,
            lease: WorkflowUncertainRetryService.claimLease,
          )).single.commandId,
          command.commandId,
        );
      });
    }
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

    test(
      'an execution StateError is not labelled a malformed payload',
      () async {
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
      },
    );

    test('a returned verification failure reaches the operator', () async {
      // Following the StateError case one caller farther. The service catches
      // the fault, records it and returns normally, so nothing throws - and
      // the released row sits back in the retry queue, which the journal
      // counts as progressing on its own. Reading only the inventory, or only
      // an exception, reports nothing wrong.
      await seedDue(
        commandId: 'cmd-good',
        payloadJson: jsonEncode(<String, Object?>{'lane': 'MECHANICAL'}),
      );
      final summary = await serviceWith(
        _Gateway.throwing(StateError('gateway fault')),
      ).retryDueCommands();

      final inventory = await repository.readOutcomeInventory();
      expect(
        inventory.needingAction,
        0,
        reason: 'the journal alone looks quiet, which is the trap',
      );
      expect(
        describeWorkflowAttention(inventory),
        isNull,
        reason: 'the inventory on its own says nothing is wrong',
      );

      expect(summary.failedVerification, <String>['cmd-good']);
      expect(
        describeWorkflowAttention(
          inventory,
          verificationIncomplete: summary.failedVerification.isNotEmpty,
        ),
        contains('could not be fully verified'),
      );
    });

    test(
      'one unresolvable command does not block the ones behind it',
      () async {
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
      },
    );

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
      expect(
        (await repository.getRetryCommand('cmd-refused'))!.stateKey,
        'rejected',
      );
    });

    test(
      'a transport failure is deferred, not mistaken for a bad payload',
      () async {
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
      },
    );
  });
}

class _OriginGateway
    implements WorkflowCommandGateway, OriginBoundWorkflowCommandGateway {
  final envelopes = <String>[];
  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async =>
      throw StateError('An origin-bound retry must never use V1.');
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    envelopes.add(envelopeJson);
    final envelope = jsonDecode(envelopeJson) as Map;
    final command = envelope['command'] as Map;
    return WorkflowCommandReceipt(
      commandId: command['commandId'] as String,
      resultKey: 'maintenance-ticket-acknowledged',
      aggregateVersion: (command['expectedVersion'] as int) + 1,
      result: const {'ticketId': 'ticket-base-205'},
      appliedAt: DateTime.utc(2026, 9, 10, 8),
    );
  }
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
  Future<void> Function()? beforeResult;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    calls += 1;
    await beforeResult?.call();
    final raised = fault;
    if (raised != null && (faultFor == null || faultFor == command.commandId)) {
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
