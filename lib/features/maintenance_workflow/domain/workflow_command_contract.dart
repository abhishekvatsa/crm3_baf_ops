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
    final appliedAt = readRequiredPersistedDateTime(
      map['appliedAt'],
      field: 'appliedAt',
      source: 'workflow command receipt',
    );
    return WorkflowCommandReceipt(
      commandId: '${map['commandId'] ?? ''}',
      resultKey: '${map['resultKey'] ?? ''}',
      aggregateVersion: (map['aggregateVersion'] as num?)?.toInt() ?? 0,
      result: Map<String, Object?>.from(
        (map['result'] as Map?) ?? const <String, Object?>{},
      ),
      appliedAt: appliedAt.toUtc(),
    );
  }
}
