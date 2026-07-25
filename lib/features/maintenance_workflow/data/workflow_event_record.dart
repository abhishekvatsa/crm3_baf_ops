import 'package:isar/isar.dart';

part 'workflow_event_record.g.dart';

@collection
class WorkflowEventRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? firestoreId;
  @Index()
  late String aggregateId;
  @Index()
  late String eventTypeKey;
  String? laneKey;
  String? representedLaneKey;
  String? actorUid;
  String? actorName;
  String? actorRolesJson;
  String? commandId;
  String payloadJson = '{}';
  @Index()
  DateTime occurredAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool isSynced = true; // events are server-authored / pull-only
}
