import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/services/critical_alarm_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

class _Gateway
    implements WorkflowCommandGateway, OriginBoundWorkflowCommandGateway {
  _Gateway(this.responses);

  final List<Object> responses;
  final List<WorkflowCommand> commands = [];
  final List<String> envelopes = [];
  void Function()? afterFirstEnvelope;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    commands.add(command);
    final response = responses.removeAt(0);
    if (response is Exception || response is Error) throw response;
    return response as WorkflowCommandReceipt;
  }

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    envelopes.add(envelopeJson);
    if (envelopes.length == 1) afterFirstEnvelope?.call();
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final commandMap = Map<String, dynamic>.from(envelope['command'] as Map);
    return execute(
      WorkflowCommand(
        commandId: commandMap['commandId'] as String,
        type: WorkflowCommandType.values.firstWhere(
          (type) => type.name == commandMap['commandType'],
        ),
        aggregateId: commandMap['aggregateId'] as String,
        expectedVersion: commandMap['expectedVersion'] as int,
        payload: Map<String, Object?>.from(commandMap['payload'] as Map),
      ),
    );
  }
}

CriticalAlarmCommandService _service(
  _Gateway gateway,
  List<ConnectivityResult> connectivity, {
  String Function()? actorUid,
  Future<List<ConnectivityResult>> Function()? checkConnectivity,
}) => CriticalAlarmCommandService(
  connectivity: Connectivity(),
  originBoundGateway: gateway,
  currentActorUid: actorUid ?? (() => 'operator-1'),
  durableStore: _durableStore,
  checkConnectivity: checkConnectivity ?? () async => connectivity,
  immediateReplayDelay: Duration.zero,
);

late Directory _directory;
late Isar _database;
late DurableSubmissionRepository _durableStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  setUp(() async {
    _directory = await Directory.systemTemp.createTemp(
      'critical_alarm_command_',
    );
    _database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: _directory.path,
      name: 'critical_alarm_command_test',
      inspector: false,
    );
    _durableStore = DurableSubmissionRepository(_database);
  });
  tearDown(() async {
    if (_database.isOpen) await _database.close(deleteFromDisk: true);
    if (_directory.existsSync()) _directory.deleteSync(recursive: true);
  });

  test(
    'offline raise retains an unsent intent before any gateway call',
    () async {
      final gateway = _Gateway([]);
      await expectLater(
        _service(gateway, const [ConnectivityResult.none]).raise(
          definition: CriticalAlarmDefinition.byKey['fire']!,
          location: 'BAF shop',
          initialDetails: 'Visible flame near the utility gallery',
        ),
        throwsA(
          isA<WorkflowException>().having(
            (error) => error.details['reasonCode'],
            'reasonCode',
            'critical-alarm-saved-offline',
          ),
        ),
      );
      expect(gateway.commands, isEmpty);
      final saved = (await _durableStore.listForActor('operator-1')).single;
      expect(saved.state, DurableSubmissionState.intent);
      expect(saved.attemptCount, 0);
    },
  );

  test(
    'uncertain response is replayed immediately with the identical command',
    () async {
      final gateway = _Gateway([
        const WorkflowException(WorkflowErrorCode.unavailable, 'response lost'),
      ]);
      // The fake must echo the command ID just as the real idempotent receipt does.
      gateway.responses.add(_EchoReceipt(gateway));
      final receipt = await _service(gateway, const [ConnectivityResult.wifi])
          .raise(
            definition: CriticalAlarmDefinition.byKey['majorGasLeakage']!,
            location: 'Gas mixing station',
            initialDetails: 'Major gas leakage suspected at the mixing station',
          );
      expect(gateway.commands, hasLength(2));
      expect(gateway.commands[1].commandId, gateway.commands[0].commandId);
      expect(gateway.commands[1].aggregateId, gateway.commands[0].aggregateId);
      expect(gateway.envelopes, hasLength(2));
      expect(
        (jsonDecode(gateway.envelopes[0]) as Map)['originActorUid'],
        'operator-1',
      );
      expect(gateway.envelopes[1], gateway.envelopes[0]);
      expect(receipt.commandId, gateway.commands[0].commandId);
    },
  );

  test(
    'an aborted response is replayed once with the identical command',
    () async {
      final gateway = _Gateway([
        const WorkflowException(
          WorkflowErrorCode.aborted,
          'transaction aborted',
        ),
      ]);
      gateway.responses.add(_EchoReceipt(gateway));
      await _service(gateway, const [ConnectivityResult.wifi]).raise(
        definition: CriticalAlarmDefinition.byKey['fire']!,
        location: 'North bay',
        initialDetails: 'Visible flame reported in the north bay',
      );
      expect(gateway.commands, hasLength(2));
      expect(gateway.commands[1].commandId, gateway.commands[0].commandId);
    },
  );

  test('a second uncertain outcome is retained for later recovery', () async {
    final gateway = _Gateway([
      const WorkflowException(WorkflowErrorCode.deadlineExceeded, 'timeout'),
      const WorkflowException(WorkflowErrorCode.unavailable, 'offline'),
    ]);
    await expectLater(
      _service(gateway, const [ConnectivityResult.mobile]).raise(
        definition: CriticalAlarmDefinition.byKey['blast']!,
        location: 'Annealing bay',
        initialDetails: 'Blast-like event reported in the annealing bay',
      ),
      throwsA(
        isA<WorkflowException>()
            .having(
              (error) => error.details['reasonCode'],
              'reasonCode',
              'critical-alarm-outcome-unconfirmed',
            )
            .having(
              (error) => error.details['commandId'],
              'commandId',
              isNotEmpty,
            ),
      ),
    );
    expect(gateway.commands, hasLength(2));
    expect(await _durableStore.listForActor('operator-1'), hasLength(1));
  });

  test(
    'a fresh service resumes the exact saved envelope after process loss',
    () async {
      final gateway = _Gateway([
        const WorkflowException(WorkflowErrorCode.unavailable, 'timeout'),
        const WorkflowException(WorkflowErrorCode.unavailable, 'still unknown'),
      ]);
      await expectLater(
        _service(gateway, const [ConnectivityResult.wifi]).raise(
          definition: CriticalAlarmDefinition.byKey['fire']!,
          location: 'North bay',
          initialDetails: 'Visible flame reported in the north bay',
        ),
        throwsA(isA<WorkflowException>()),
      );
      final pending = await _durableStore.listForActor('operator-1');
      expect(pending, hasLength(1));
      final originalEnvelope = gateway.envelopes.first;
      await _database.close();
      _database = await Isar.open(
        [DurableSubmissionRecordSchema],
        directory: _directory.path,
        name: 'critical_alarm_command_test',
        inspector: false,
      );
      _durableStore = DurableSubmissionRepository(_database);

      final recoveryGateway = _Gateway([]);
      recoveryGateway.responses.add(_EchoReceipt(recoveryGateway));
      final receipt = await _service(recoveryGateway, const [
        ConnectivityResult.wifi,
      ]).resume(pending.single.submissionId);

      expect(receipt.commandId, pending.single.requestId);
      expect(recoveryGateway.envelopes, [originalEnvelope]);
    },
  );

  test('freezes the original actor before a delayed replay', () async {
    var actor = 'operator-1';
    final gateway = _Gateway([
      const WorkflowException(WorkflowErrorCode.unavailable, 'response lost'),
      const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'the current account is not the origin account',
      ),
    ]);
    gateway.afterFirstEnvelope = () => actor = 'operator-2';

    await expectLater(
      _service(gateway, const [
        ConnectivityResult.wifi,
      ], actorUid: () => actor).raise(
        definition: CriticalAlarmDefinition.byKey['fire']!,
        location: 'North bay',
        initialDetails: 'Visible flame reported in the north bay',
      ),
      throwsA(
        isA<WorkflowException>().having(
          (error) => error.code,
          'code',
          WorkflowErrorCode.permissionDenied,
        ),
      ),
    );
    expect(gateway.envelopes, hasLength(1));
    expect(
      (jsonDecode(gateway.envelopes[0]) as Map)['originActorUid'],
      'operator-1',
    );
    final retained = (await _durableStore.listForActor('operator-1')).single;
    expect(retained.state, DurableSubmissionState.uncertain);
    expect(retained.envelopeJson, gateway.envelopes.single);
    actor = 'operator-1';
    final recovery = _Gateway([]);
    recovery.responses.add(_EchoReceipt(recovery));
    await _service(recovery, const [
      ConnectivityResult.wifi,
    ], actorUid: () => actor).resume(retained.submissionId);
    expect(recovery.envelopes, [retained.envelopeJson]);
  });

  for (final failure in [
    const WorkflowException(
      WorkflowErrorCode.permissionDenied,
      'Approval cannot be verified.',
      details: {'reasonCode': 'workflow-actor-authority-invalid'},
    ),
    const WorkflowException(WorkflowErrorCode.unauthenticated, 'Signed out.'),
    const WorkflowException(WorkflowErrorCode.internal, 'Backend error.'),
    const WorkflowException(WorkflowErrorCode.resourceExhausted, 'Busy.'),
    const WorkflowException(
      WorkflowErrorCode.failedPrecondition,
      'Accepted evidence needs review.',
      details: {'reasonCode': 'critical-alarm-replay-evidence-invalid'},
    ),
    const WorkflowException(
      WorkflowErrorCode.failedPrecondition,
      'Audit exists without its receipt.',
      details: {'reasonCode': 'critical-alarm-audit-orphan'},
    ),
    const WorkflowException(
      WorkflowErrorCode.failedPrecondition,
      'The catalogue reason is currently retired.',
      details: {'reasonCode': 'critical-alarm-type-retired'},
    ),
  ]) {
    test(
      'reopened uncertain command survives ${failure.code.name}/${failure.details['reasonCode']}',
      () async {
        final first = _Gateway([
          const WorkflowException(WorkflowErrorCode.unavailable, 'Lost reply'),
          const WorkflowException(WorkflowErrorCode.unavailable, 'Lost replay'),
        ]);
        await expectLater(
          _service(first, const [ConnectivityResult.wifi]).raise(
            definition: CriticalAlarmDefinition.byKey['fire']!,
            location: 'Synthetic bay',
            initialDetails: 'Synthetic test incident',
          ),
          throwsA(isA<WorkflowException>()),
        );
        final saved = (await _durableStore.listForActor('operator-1')).single;
        await _database.close();
        _database = await Isar.open(
          [DurableSubmissionRecordSchema],
          directory: _directory.path,
          name: 'critical_alarm_command_test',
          inspector: false,
        );
        _durableStore = DurableSubmissionRepository(_database);
        final refused = _Gateway([failure]);
        await expectLater(
          _service(refused, const [
            ConnectivityResult.wifi,
          ]).resume(saved.submissionId),
          throwsA(
            isA<WorkflowException>().having(
              (e) => e.code,
              'code',
              failure.code,
            ),
          ),
        );
        final retained = (await _durableStore.listForActor(
          'operator-1',
        )).single;
        expect(retained.state, DurableSubmissionState.uncertain);
        expect(retained.claimToken, isNull);
        expect(retained.envelopeJson, saved.envelopeJson);
        final restored = _Gateway([]);
        restored.responses.add(_EchoReceipt(restored));
        final receipt = await _service(restored, const [
          ConnectivityResult.wifi,
        ]).resume(saved.submissionId);
        expect(restored.envelopes, [saved.envelopeJson]);
        expect(receipt.commandId, saved.requestId);
      },
    );
  }

  test(
    'account switch during connectivity preserves unsent original',
    () async {
      var actor = 'operator-1';
      final entered = Completer<void>();
      final connection = Completer<List<ConnectivityResult>>();
      final gateway = _Gateway([]);
      final operation =
          _service(
            gateway,
            const [],
            actorUid: () => actor,
            checkConnectivity: () {
              entered.complete();
              return connection.future;
            },
          ).raise(
            definition: CriticalAlarmDefinition.byKey['fire']!,
            location: 'Synthetic bay',
            initialDetails: 'Synthetic test incident',
          );
      final refusal = expectLater(
        operation,
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'critical-alarm-origin-actor-mismatch',
          ),
        ),
      );
      await entered.future;
      actor = 'operator-2';
      connection.complete([ConnectivityResult.wifi]);
      await refusal;
      final retained = (await _durableStore.listForActor('operator-1')).single;
      expect(retained.state, DurableSubmissionState.intent);
      expect(retained.attemptCount, 0);
      expect(gateway.envelopes, isEmpty);
      expect(await _durableStore.listForActor('operator-2'), isEmpty);
      actor = 'operator-1';
      gateway.responses.add(_EchoReceipt(gateway));
      await _service(gateway, const [
        ConnectivityResult.wifi,
      ], actorUid: () => actor).resume(retained.submissionId);
      expect(gateway.envelopes, [retained.envelopeJson]);
    },
  );

  test(
    'accepted reply after account switch remains pending for original actor',
    () async {
      var actor = 'operator-1';
      final gateway = _Gateway([]);
      gateway.responses.add(_EchoReceipt(gateway));
      gateway.afterFirstEnvelope = () => actor = 'operator-2';
      await expectLater(
        _service(gateway, const [
          ConnectivityResult.wifi,
        ], actorUid: () => actor).raise(
          definition: CriticalAlarmDefinition.byKey['fire']!,
          location: 'Synthetic bay',
          initialDetails: 'Synthetic test incident',
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowErrorCode.permissionDenied,
          ),
        ),
      );
      final saved = (await _durableStore.listForActor('operator-1')).single;
      expect(saved.state, DurableSubmissionState.acceptedPendingAdoption);
      expect(saved.receiptJson, isNotNull);
      final restored = _Gateway([]);
      await expectLater(
        _service(restored, const [
          ConnectivityResult.wifi,
        ], actorUid: () => actor).resume(saved.submissionId),
        throwsA(isA<WorkflowException>()),
      );
      expect(restored.envelopes, isEmpty);
      actor = 'operator-1';
      final receipt = await _service(restored, const [
        ConnectivityResult.none,
      ], actorUid: () => actor).resume(saved.submissionId);
      expect(receipt.commandId, saved.requestId);
      expect(restored.envelopes, isEmpty);
      expect(
        (await _durableStore.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  for (final secondAttempt in [false, true]) {
    test(
      'unexpected failure on attempt ${secondAttempt ? 2 : 1} releases claim without rejecting',
      () async {
        final gateway = _Gateway([
          if (secondAttempt)
            const WorkflowException(
              WorkflowErrorCode.unavailable,
              'Lost reply',
            ),
          StateError('Synthetic unexpected gateway failure'),
        ]);
        await expectLater(
          _service(gateway, const [ConnectivityResult.wifi]).raise(
            definition: CriticalAlarmDefinition.byKey['fire']!,
            location: 'Synthetic bay',
            initialDetails: 'Synthetic test incident',
          ),
          throwsA(isA<StateError>()),
        );
        final saved = (await _durableStore.listForActor('operator-1')).single;
        expect(saved.state, DurableSubmissionState.uncertain);
        expect(saved.claimToken, isNull);
        final recovery = _Gateway([]);
        recovery.responses.add(_EchoReceipt(recovery));
        await _service(recovery, const [
          ConnectivityResult.wifi,
        ]).resume(saved.submissionId);
        expect(recovery.envelopes, [saved.envelopeJson]);
      },
    );
  }

  for (final reason in [
    'critical-alarm-type-retired',
    'unrecognized-refusal',
  ]) {
    test(
      'only a named post-receipt business refusal becomes terminal: $reason',
      () async {
        final gateway = _Gateway([
          WorkflowException(
            WorkflowErrorCode.failedPrecondition,
            'Reason unavailable.',
            details: {'reasonCode': reason},
          ),
        ]);
        await expectLater(
          _service(gateway, const [ConnectivityResult.wifi]).raise(
            definition: CriticalAlarmDefinition.byKey['fire']!,
            location: 'Synthetic bay',
            initialDetails: 'Synthetic test incident',
          ),
          throwsA(isA<WorkflowException>()),
        );
        final saved = (await _durableStore.listForActor(
          'operator-1',
          includeTerminal: true,
        )).single;
        expect(
          saved.state,
          reason == 'critical-alarm-type-retired'
              ? DurableSubmissionState.rejected
              : DurableSubmissionState.uncertain,
        );
        expect(saved.envelopeJson, gateway.envelopes.single);
      },
    );
  }
  test(
    'timeout then catalogue refusal cannot reject a delayed original attempt',
    () async {
      final gateway = _Gateway([
        const WorkflowException(WorkflowErrorCode.unavailable, 'Lost reply'),
        const WorkflowException(
          WorkflowErrorCode.failedPrecondition,
          'Reason retired.',
          details: {'reasonCode': 'critical-alarm-type-retired'},
        ),
      ]);
      await expectLater(
        _service(gateway, const [ConnectivityResult.wifi]).raise(
          definition: CriticalAlarmDefinition.byKey['fire']!,
          location: 'Synthetic bay',
          initialDetails: 'Synthetic test incident',
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.details['reasonCode'],
            'reason',
            'critical-alarm-outcome-unconfirmed',
          ),
        ),
      );
      final saved = (await _durableStore.listForActor('operator-1')).single;
      expect(saved.state, DurableSubmissionState.uncertain);
      expect(gateway.envelopes, [saved.envelopeJson, saved.envelopeJson]);
      final restored = _Gateway([]);
      restored.responses.add(_EchoReceipt(restored));
      final receipt = await _service(restored, const [
        ConnectivityResult.wifi,
      ]).resume(saved.submissionId);
      expect(receipt.commandId, saved.requestId);
      expect(restored.envelopes, [saved.envelopeJson]);
    },
  );
}

class _EchoReceipt implements WorkflowCommandReceipt {
  _EchoReceipt(this.gateway);

  final _Gateway gateway;

  @override
  String get commandId => gateway.commands.last.commandId;

  @override
  int get aggregateVersion => 1;

  @override
  DateTime get appliedAt => DateTime.utc(2026, 8, 26);

  @override
  Map<String, Object?> get result => const {'detailsPending': true};

  @override
  String get resultKey => 'critical-alarm-raised';
}
