import 'dart:math';

import '../domain/workflow_command_contract.dart';
import '../domain/workflow_types.dart';

abstract final class WorkflowCommandFactory {
  static final Random _random = Random.secure();

  static String uniqueId(String prefix, {DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    final entropy = List<int>.generate(6, (_) => _random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${prefix}_${timestamp}_$entropy';
  }

  static WorkflowCommand create({
    required WorkflowCommandType type,
    required String aggregateId,
    required int expectedVersion,
    Map<String, Object?> payload = const <String, Object?>{},
    DateTime? now,
  }) {
    final commandId = uniqueId('${type.name}_$aggregateId', now: now);
    return WorkflowCommand(
      commandId: commandId,
      type: type,
      aggregateId: aggregateId,
      expectedVersion: expectedVersion,
      payload: payload,
    );
  }
}
