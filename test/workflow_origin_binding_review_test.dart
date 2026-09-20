import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_uncertain_retry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

class _Repository extends IsarWorkflowRepository {
  _Repository(super.isar);
  bool failPreparation = false;
  bool failSettlement = false;

  @override
  Future<WorkflowRetryTransition> applyRetryTransitionUnlessAccepted({
    required String commandId,
    required WorkflowCommandRecord? Function(WorkflowCommandRecord?) build,
  }) {
    if (failPreparation) throw StateError('Synthetic native write failure');
    return super.applyRetryTransitionUnlessAccepted(
      commandId: commandId,
      build: build,
    );
  }

  @override
  Future<void> settleAccepted(WorkflowCommandReceiptRecord receipt) {
    if (failSettlement) {
      throw StateError('Synthetic receipt settlement failure');
    }
    return super.settleAccepted(receipt);
  }
}

class _Gateway
    implements WorkflowCommandGateway, OriginBoundWorkflowCommandGateway {
  final List<String> envelopes = [];
  int legacyCalls = 0;
  Future<void> Function()? onDispatch;
  Object? failure;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    legacyCalls++;
    throw StateError('Origin-bound tests must not dispatch through V1');
  }

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(String raw) async {
    envelopes.add(raw);
    await onDispatch?.call();
    if (failure != null) throw failure!;
    final command = (jsonDecode(raw) as Map)['command'] as Map;
    return WorkflowCommandReceipt(
      commandId: command['commandId'] as String,
      resultKey: 'lane-acknowledged',
      aggregateVersion: (command['expectedVersion'] as int) + 1,
      result: {'workflowId': command['aggregateId'], 'lane': 'mechanical'},
      appliedAt: DateTime.utc(2026, 9, 20, 5),
    );
  }
}

WorkflowCommand _command({Map<String, Object?>? payload}) => WorkflowCommand(
  commandId: 'origin-command-1',
  type: WorkflowCommandType.acknowledgeLane,
  aggregateId: 'workflow-1',
  expectedVersion: 3,
  payload: payload ?? const {'lane': 'mechanical'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late _Repository repository;
  late _Gateway gateway;
  late String? actor;
  late DateTime clock;
  late bool online;

  Future<void> open() async {
    database = await Isar.open(
      [WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema],
      directory: directory.path,
      name: 'workflow_origin_review',
      inspector: false,
    );
    repository = _Repository(database);
  }

  WorkflowOnlineExecutor executor({
    Future<List<ConnectivityResult>> Function()? connection,
  }) => WorkflowOnlineExecutor(
    connectivity: Connectivity(),
    gateway: gateway,
    repository: repository,
    now: () => clock,
    originActorUid: () => actor,
    checkConnectivity:
        connection ??
        () async => [
          online ? ConnectivityResult.wifi : ConnectivityResult.none,
        ],
  );

  WorkflowUncertainRetryService retry() => WorkflowUncertainRetryService(
    repository: repository,
    executor: executor(),
    now: () => clock,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'workflow_origin_review_',
    );
    await open();
    gateway = _Gateway();
    actor = 'actor-a';
    online = true;
    clock = DateTime.utc(2026, 9, 20, 5);
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  test(
    'origin is captured before connectivity, and a switched account cannot send',
    () async {
      final gate = Completer<List<ConnectivityResult>>();
      final call = executor(connection: () => gate.future).execute(_command());
      final result = expectLater(
        call,
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'workflow-origin-changed',
          ),
        ),
      );
      actor = 'actor-b';
      gate.complete([ConnectivityResult.wifi]);
      await result;
      expect(gateway.envelopes, isEmpty);
      expect(gateway.legacyCalls, 0);
      expect(await repository.getRetryCommand(_command().commandId), isNull);
    },
  );

  test('a missing production actor never falls through to V1', () async {
    actor = null;
    await expectLater(
      executor().execute(_command()),
      throwsA(
        isA<WorkflowException>().having(
          (e) => e.code,
          'code',
          WorkflowErrorCode.unauthenticated,
        ),
      ),
    );
    expect(gateway.legacyCalls, 0);
    expect(gateway.envelopes, isEmpty);
  });

  for (final type in [
    WorkflowCommandType.recordInspectionObservation,
    WorkflowCommandType.linkInspectionObservationIssue,
    WorkflowCommandType.verifyInspectionFinding,
    WorkflowCommandType.adjudicateInspectionFinding,
    WorkflowCommandType.revalidateInspectionTargetContext,
    WorkflowCommandType.setInspectionCampaignStatus,
  ]) {
    test(
      'inspection ${type.name} preserves original intent across native reopen and account switch',
      () async {
        // This exercises the production native journal/retry boundary, not the
        // server's business validation (covered by actual-handler tests).
        final command = WorkflowCommand(
          commandId: 'inspection-${type.name}',
          type: type,
          aggregateId: 'survey-1',
          expectedVersion: 7,
          payload: const {
            'observationId': 'reading-1',
            'findingId': 'finding-1',
            'historicalAmendmentReason':
                'Correct the original instrument reading.',
            'followUpFindingId': 'finding-1',
            'value': {'numericValue': 2.8},
          },
        );
        gateway.failure = const WorkflowException(
          WorkflowErrorCode.unavailable,
          'Reply lost after dispatch',
        );
        await expectLater(
          executor().execute(command),
          throwsA(isA<WorkflowException>()),
        );
        final original = gateway.envelopes.single;
        final bytes = (await repository.getRetryCommand(
          command.commandId,
        ))!.payloadJson;
        await database.close();
        await open();
        gateway.failure = null;
        actor = 'actor-b';
        clock = clock.add(const Duration(minutes: 6));
        await retry().retryDueCommands();
        expect(gateway.envelopes, [original]);
        expect(
          (await repository.getRetryCommand(command.commandId))!.payloadJson,
          bytes,
        );
        actor = 'actor-a';
        clock = clock.add(const Duration(minutes: 6));
        expect((await retry().retryDueCommands()).applied, [command.commandId]);
        expect(gateway.envelopes, [original, original]);
        expect(await repository.getRetryCommand(command.commandId), isNull);
        await executor().execute(command);
        expect(gateway.envelopes, [original, original]);
        expect(gateway.legacyCalls, 0);
      },
    );
  }

  test('nested request input is detached before the first await', () async {
    final nested = <String, Object?>{'note': 'original'};
    final gate = Completer<List<ConnectivityResult>>();
    final call = executor(
      connection: () => gate.future,
    ).execute(_command(payload: {'lane': 'mechanical', 'nested': nested}));
    nested['note'] = 'changed';
    gate.complete([ConnectivityResult.wifi]);
    await call;
    final sent =
        (jsonDecode(gateway.envelopes.single) as Map)['command'] as Map;
    expect((sent['payload'] as Map)['nested'], {'note': 'original'});
  });

  test(
    'failed native preparation sends nothing and never creates a failure-owned replacement',
    () async {
      repository.failPreparation = true;
      await expectLater(
        executor().execute(_command()),
        throwsA(isA<StateError>()),
      );
      expect(gateway.envelopes, isEmpty);
      expect(await repository.getRetryCommand(_command().commandId), isNull);
    },
  );

  test(
    'failure after account change retains actor A and resumes A exact envelope after native reopen',
    () async {
      gateway.onDispatch = () async {
        actor = 'actor-b';
      };
      gateway.failure = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Lost reply',
      );
      await expectLater(
        executor().execute(_command()),
        throwsA(isA<WorkflowException>()),
      );
      final saved = (await repository.getRetryCommand(_command().commandId))!;
      final bytes = saved.payloadJson;
      final envelope = gateway.envelopes.single;
      expect((jsonDecode(bytes) as Map)['__workflowOriginBoundV1'], 'actor-a');
      await database.close();
      await open();
      clock = clock.add(const Duration(minutes: 2));
      gateway.onDispatch = null;
      gateway.failure = null;
      final otherActorRun = await retry().retryDueCommands();
      expect(otherActorRun.applied, isEmpty);
      expect(gateway.envelopes, [envelope]);
      expect(
        (await repository.getRetryCommand(saved.commandId))!.payloadJson,
        bytes,
      );
      actor = 'actor-a';
      clock = clock.add(const Duration(minutes: 2));
      final originalActorRun = await retry().retryDueCommands();
      expect(originalActorRun.applied, [saved.commandId]);
      expect(gateway.envelopes, [envelope, envelope]);
      expect(gateway.legacyCalls, 0);
    },
  );

  test(
    'receipt settlement failure leaves the pre-dispatch identity recoverable after Isar reopen',
    () async {
      repository.failSettlement = true;
      final accepted = await executor().execute(_command());
      final saved = (await repository.getRetryCommand(_command().commandId))!;
      expect(saved.stateKey, 'sending');
      expect(await repository.getReceipt(saved.commandId), isNull);
      final originalEnvelope = gateway.envelopes.single;
      await database.close();
      await open();
      clock = clock.add(const Duration(minutes: 6));
      final recovered = await retry().retryDueCommands();
      expect(recovered.applied, [accepted.commandId]);
      expect(gateway.envelopes, [originalEnvelope, originalEnvelope]);
      expect(await repository.getRetryCommand(saved.commandId), isNull);
      expect(await repository.getReceipt(saved.commandId), isNotNull);
    },
  );

  test('same-ID changed payload cannot overwrite pending original', () async {
    gateway.failure = const WorkflowException(
      WorkflowErrorCode.unavailable,
      'Lost reply',
    );
    await expectLater(
      executor().execute(_command()),
      throwsA(isA<WorkflowException>()),
    );
    final original = (await repository.getRetryCommand(_command().commandId))!;
    clock = clock.add(const Duration(minutes: 1));
    await expectLater(
      executor().execute(_command(payload: {'lane': 'electrical'})),
      throwsA(
        isA<WorkflowException>().having(
          (e) => e.details['reasonCode'],
          'reason',
          'workflow-local-envelope-conflict',
        ),
      ),
    );
    final current = (await repository.getRetryCommand(original.commandId))!;
    expect(current.payloadJson, original.payloadJson);
    expect(current.stateKey, original.stateKey);
    expect(current.lastAttemptAt, original.lastAttemptAt);
    expect(current.attemptCount, original.attemptCount);
    expect(gateway.envelopes, hasLength(1));
  });

  test('foreground duplicate cannot borrow an active claim', () async {
    final entered = Completer<void>();
    final reply = Completer<void>();
    gateway.onDispatch = () {
      entered.complete();
      return reply.future;
    };
    final first = executor().execute(_command());
    await entered.future;
    await expectLater(
      executor().execute(_command()),
      throwsA(
        isA<WorkflowException>().having(
          (e) => e.details['reasonCode'],
          'reason',
          'workflow-command-not-dispatchable',
        ),
      ),
    );
    expect(gateway.envelopes, hasLength(1));
    reply.complete();
    await first;
    expect(await repository.getRetryCommand(_command().commandId), isNull);
  });

  for (final state in ['uncertainOutcome', 'rejected', 'manualReview']) {
    test(
      'legacy $state ownerless bytes are never attributed or auto-reactivated',
      () async {
        const raw = '{"lane" : "mechanical"}';
        await repository.saveRetryCommand(
          WorkflowCommandRecord()
            ..commandId = _command().commandId
            ..aggregateId = _command().aggregateId
            ..commandTypeKey = _command().type.name
            ..expectedVersion = 3
            ..payloadJson = raw
            ..stateKey = state
            ..attemptCount = 2
            ..createdLocallyAt = clock.subtract(const Duration(hours: 1))
            ..nextRetryAt = clock.subtract(const Duration(minutes: 1)),
        );
        final result = await retry().retryDueCommands();
        expect(result.applied, isEmpty);
        expect(gateway.envelopes, isEmpty);
        final saved = (await repository.getRetryCommand(_command().commandId))!;
        expect(saved.payloadJson, raw);
        expect(saved.attemptCount, 2);
        expect(
          saved.stateKey,
          state == 'uncertainOutcome' ? 'manualReview' : state,
        );
      },
    );
  }

  test(
    'malformed saved origin bytes survive native reopen and review hold',
    () async {
      const raw = '{"__workflowOriginBoundV1":"actor-a", "payload":';
      final createdAt = clock.subtract(const Duration(hours: 1));
      await repository.saveRetryCommand(
        WorkflowCommandRecord()
          ..commandId = _command().commandId
          ..aggregateId = _command().aggregateId
          ..commandTypeKey = _command().type.name
          ..expectedVersion = 3
          ..payloadJson = raw
          ..stateKey = 'uncertainOutcome'
          ..attemptCount = 2
          ..createdLocallyAt = createdAt
          ..nextRetryAt = clock.subtract(const Duration(minutes: 1)),
      );
      await database.close();
      await open();
      await expectLater(
        executor().execute(_command()),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'workflow-legacy-origin-review-required',
          ),
        ),
      );
      final saved = (await repository.getRetryCommand(_command().commandId))!;
      expect(saved.payloadJson, raw);
      expect(saved.createdLocallyAt.toUtc(), createdAt.toUtc());
      expect(saved.attemptCount, 2);
      expect(saved.stateKey, 'manualReview');
      expect(saved.lastErrorCode, 'workflow-legacy-origin-review-required');
      expect(saved.nextRetryAt, isNull);
      expect(await repository.getReceipt(_command().commandId), isNull);
      expect(gateway.envelopes, isEmpty);
      expect(gateway.legacyCalls, 0);
    },
  );

  test(
    'accepted local capsule binds actor and full command across native reopen',
    () async {
      final accepted = await executor().execute(_command());
      final original = (await repository.getReceipt(
        accepted.commandId,
      ))!.resultJson;
      await database.close();
      await open();
      online = false;
      final recovered = await executor().execute(_command());
      expect(recovered.result, accepted.result);
      expect(
        recovered.result.keys,
        isNot(contains('__workflowAcceptedEnvelopeV1')),
      );
      actor = 'actor-b';
      await expectLater(
        executor().execute(_command()),
        throwsA(isA<WorkflowException>()),
      );
      actor = 'actor-a';
      online = true;
      await expectLater(
        executor().execute(_command(payload: {'lane': 'electrical'})),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'workflow-local-acceptance-origin-unverified',
          ),
        ),
      );
      expect(
        (await repository.getReceipt(accepted.commandId))!.resultJson,
        original,
      );
      expect(gateway.envelopes, hasLength(1));
    },
  );

  test(
    'acceptance arriving after account change is stored for origin but not returned to replacement',
    () async {
      gateway.onDispatch = () async {
        actor = 'actor-b';
      };
      await expectLater(
        executor().execute(_command()),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'workflow-origin-changed',
          ),
        ),
      );
      expect(await repository.getReceipt(_command().commandId), isNotNull);
      expect(await repository.getRetryCommand(_command().commandId), isNull);
      actor = 'actor-a';
      online = false;
      final receipt = await executor().execute(_command());
      expect(receipt.commandId, _command().commandId);
      expect(gateway.envelopes, hasLength(1));
    },
  );

  test(
    'controller cannot return prior actor receipt after awaited projection refresh',
    () async {
      final accepted = await executor().execute(_command());
      final controller = WorkflowCommandController.forTesting(
        executeCommand: (_) async => accepted,
        pullProjections: () async {
          actor = 'actor-b';
        },
        currentActorUid: () => actor,
      );
      addTearDown(controller.dispose);
      await expectLater(
        controller.execute(_command()),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowErrorCode.permissionDenied,
          ),
        ),
      );
      expect(controller.state.hasError, isTrue);
    },
  );
}
