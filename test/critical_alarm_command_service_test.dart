import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/services/critical_alarm_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

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
    if (response is WorkflowException) throw response;
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
}) => CriticalAlarmCommandService(
  connectivity: Connectivity(),
  originBoundGateway: gateway,
  currentActorUid: actorUid ?? (() => 'operator-1'),
  checkConnectivity: () async => connectivity,
  immediateReplayDelay: Duration.zero,
);

void main() {
  test(
    'offline raise is rejected before a command reaches the gateway',
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
            'critical-alarm-not-dispatched-offline',
          ),
        ),
      );
      expect(gateway.commands, isEmpty);
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

  test('a second uncertain outcome is not persisted for later retry', () async {
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
  });

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
    expect(gateway.envelopes, hasLength(2));
    expect(
      (jsonDecode(gateway.envelopes[0]) as Map)['originActorUid'],
      'operator-1',
    );
    expect(gateway.envelopes[1], gateway.envelopes[0]);
  });
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
