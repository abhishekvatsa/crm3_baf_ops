import 'package:isar/isar.dart';

part 'workflow_command_record.g.dart';

/// Local retry record for online-only workflow commands.
///
/// The app does not intentionally accept new lifecycle commands while offline.
/// A row is retained only when the request may have reached the server but the
/// response was lost, allowing safe replay with the same commandId.
@collection
class WorkflowCommandRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String commandId;

  @Index()
  late String aggregateId;

  @Index()
  late String commandTypeKey;

  int expectedVersion = 0;
  String payloadJson = '{}';

  @Index()
  String stateKey = 'ready'; // ready | sending | uncertainOutcome | applied | rejected | manualReview

  int attemptCount = 0;
  DateTime createdLocallyAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime? lastAttemptAt;
  DateTime? nextRetryAt;
  String? lastErrorCode;
  String? lastErrorMessage;
  String? receiptJson;
}
