import 'package:isar/isar.dart';

part 'workflow_command_receipt_record.g.dart';

@collection
class WorkflowCommandReceiptRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String commandId;

  @Index()
  late String aggregateId;

  late String resultKey;
  int aggregateVersion = 0;
  String resultJson = '{}';
  DateTime appliedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
