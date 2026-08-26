import 'package:connectivity_plus/connectivity_plus.dart';

import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../domain/critical_alarm_models.dart';

class CriticalAlarmCommandService {
  const CriticalAlarmCommandService({
    required this.connectivity,
    required this.gateway,
    this.checkConnectivity,
    this.immediateReplayDelay = const Duration(milliseconds: 250),
  });

  final Connectivity connectivity;
  final WorkflowCommandGateway gateway;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Duration immediateReplayDelay;

  Future<WorkflowCommandReceipt> _execute(WorkflowCommand command) async {
    final result =
        await (checkConnectivity?.call() ?? connectivity.checkConnectivity());
    if (result.every((entry) => entry == ConnectivityResult.none)) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'No alarm was queued. Follow the plant emergency procedure and retry only when connectivity is available.',
        details: {'reasonCode': 'critical-alarm-not-dispatched-offline'},
      );
    }
    try {
      return await gateway.execute(command);
    } on WorkflowException catch (error) {
      if (!_isUncertain(error)) rethrow;
      if (immediateReplayDelay > Duration.zero) {
        await Future<void>.delayed(immediateReplayDelay);
      }
      try {
        // Same command ID: a committed first attempt resolves as an
        // idempotent replay, while a genuinely failed attempt executes once.
        return await gateway.execute(command);
      } on WorkflowException catch (replayError) {
        if (!_isUncertain(replayError)) rethrow;
        throw WorkflowException(
          replayError.code,
          'The critical-safety command outcome could not be confirmed. No delayed retry was queued. Check the live server feed before submitting again.',
          details: {
            ...replayError.details,
            'reasonCode': 'critical-alarm-outcome-unconfirmed',
            'commandId': command.commandId,
            'aggregateId': command.aggregateId,
          },
        );
      }
    }
  }

  bool _isUncertain(WorkflowException error) =>
      error.code == WorkflowErrorCode.unavailable ||
      error.code == WorkflowErrorCode.deadlineExceeded ||
      error.code == WorkflowErrorCode.aborted;

  Future<WorkflowCommandReceipt> raise({
    required CriticalAlarmDefinition definition,
    required String location,
    String? assetTypeKey,
    int? assetNumber,
    String? initialDetails,
  }) {
    final alarmId = WorkflowCommandFactory.uniqueId('critical_alarm');
    return _execute(
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.raiseCriticalAlarm,
        aggregateId: alarmId,
        expectedVersion: 0,
        payload: {
          'alarmTypeKey': definition.key,
          'location': location,
          'assetTypeKey': assetTypeKey,
          'assetNumber': assetNumber,
          'initialDetails': initialDetails,
        },
      ),
    );
  }

  Future<WorkflowCommandReceipt> provideDetails(
    CriticalAlarm alarm,
    String details,
  ) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.provideCriticalAlarmDetails,
      aggregateId: alarm.id,
      expectedVersion: alarm.version,
      payload: {'details': details},
    ),
  );

  Future<WorkflowCommandReceipt> confirmSupport({
    required CriticalAlarm alarm,
    required CriticalAlarmSupportBasis basis,
    required String responderNote,
    String? details,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.confirmCriticalAlarmSupport,
      aggregateId: alarm.id,
      expectedVersion: alarm.version,
      payload: {
        'basis': basis.name,
        'responderNote': responderNote,
        'details': details,
      },
    ),
  );

  Future<WorkflowCommandReceipt> resolve(CriticalAlarm alarm, String summary) =>
      _execute(
        WorkflowCommandFactory.create(
          type: WorkflowCommandType.resolveCriticalAlarm,
          aggregateId: alarm.id,
          expectedVersion: alarm.version,
          payload: {'resolutionSummary': summary},
        ),
      );

  Future<WorkflowCommandReceipt> withdraw(CriticalAlarm alarm, String reason) =>
      _execute(
        WorkflowCommandFactory.create(
          type: WorkflowCommandType.withdrawCriticalAlarmInError,
          aggregateId: alarm.id,
          expectedVersion: alarm.version,
          payload: {'reason': reason},
        ),
      );

  Future<WorkflowCommandReceipt> upsertContact({
    required String contactId,
    required int expectedVersion,
    required String label,
    required CriticalAlarmContactKind kind,
    required String dialValue,
    required List<String> alarmTypeKeys,
    required int priority,
    required String? notes,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.upsertCriticalAlarmContact,
      aggregateId: contactId,
      expectedVersion: expectedVersion,
      payload: {
        'contact': {
          'schemaVersion': 1,
          'label': label,
          'contactKind': kind.name,
          'dialValue': dialValue,
          'alarmTypeKeys': alarmTypeKeys,
          'priority': priority,
          'notes': notes,
        },
        'reason': reason,
      },
    ),
  );

  Future<WorkflowCommandReceipt> setContactStatus({
    required CriticalAlarmContact contact,
    required CriticalAlarmContactStatus status,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.setCriticalAlarmContactStatus,
      aggregateId: contact.id,
      expectedVersion: contact.version,
      payload: {'status': status.name, 'reason': reason},
    ),
  );
}
