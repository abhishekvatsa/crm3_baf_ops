import '../../../core/serialization/persisted_data_reader.dart';
import 'workflow_error.dart';
import 'workflow_types.dart';

class WorkflowCommand {
  final String commandId;
  final WorkflowCommandType type;
  final String aggregateId;
  final int expectedVersion;
  final Map<String, Object?> payload;

  WorkflowCommand({
    required String commandId,
    required this.type,
    required String aggregateId,
    required this.expectedVersion,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : commandId = commandId.trim(),
       aggregateId = aggregateId.trim(),
       payload = Map.unmodifiable(payload) {
    if (this.commandId.isEmpty ||
        this.aggregateId.isEmpty ||
        expectedVersion < 0) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'Command ID, aggregate ID and non-negative version are required.',
      );
    }
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'commandId': commandId,
    'commandType': type.name,
    'aggregateId': aggregateId,
    'expectedVersion': expectedVersion,
    'payload': payload,
  };
}

class WorkflowCommandReceipt {
  final String commandId;
  final String resultKey;
  final int aggregateVersion;
  final Map<String, Object?> result;
  final DateTime appliedAt;

  const WorkflowCommandReceipt({
    required this.commandId,
    required this.resultKey,
    required this.aggregateVersion,
    required this.result,
    required this.appliedAt,
  });

  factory WorkflowCommandReceipt.fromMap(Map<String, dynamic> map) {
    const source = 'workflow command receipt';
    final appliedAtRaw = map['appliedAt'];
    final appliedAt = readRequiredPersistedDateTime(
      map['appliedAt'],
      field: 'appliedAt',
      source: source,
    );
    if (appliedAtRaw is! String ||
        appliedAtRaw.trim() != appliedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'appliedAt',
        source: source,
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    final result = readOptionalBoundedJsonObject(
      map['result'],
      field: 'result',
      source: source,
    );
    if (result == null) {
      throw PersistedDataFormatException(
        field: 'result',
        source: source,
        detail: 'required result object',
      );
    }
    const expectedFields = <String>{
      'commandId',
      'resultKey',
      'aggregateVersion',
      'result',
      'appliedAt',
    };
    final receivedFields = map.keys.toSet();
    if (receivedFields.length != expectedFields.length ||
        !receivedFields.containsAll(expectedFields)) {
      throw PersistedDataFormatException(
        field: 'response',
        source: source,
        detail: 'response field set does not match the command contract',
      );
    }
    return WorkflowCommandReceipt(
      commandId: readRequiredPersistedString(
        map['commandId'],
        field: 'commandId',
        source: source,
      ),
      resultKey: readRequiredPersistedString(
        map['resultKey'],
        field: 'resultKey',
        source: source,
      ),
      aggregateVersion: readRequiredPersistedInt(
        map['aggregateVersion'],
        field: 'aggregateVersion',
        source: source,
        minimum: 1,
      ),
      result: Map<String, Object?>.unmodifiable(result),
      appliedAt: appliedAt,
    );
  }
}
