import 'package:isar/isar.dart';

part 'workflow_aggregate_record.g.dart';

@collection
class WorkflowAggregateRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String firestoreId;

  @Index()
  late String jobExecutionFirestoreId;

  @Index()
  late String assetTypeKey;

  @Index()
  late int assetNumber;

  @Index()
  String statusKey = 'pendingLaneClassification';

  int workflowSchemaVersion = 1;
  int version = 0;
  int laneSetVersion = 0;
  DateTime? laneSetFinalizedAt;
  String? laneSetFinalizedByUid;
  String? laneSetFinalizedByName;
  bool activeRedWork = false;
  bool awaitingPreparation = false;
  bool cancelled = false;
  DateTime? completedAt;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? metadataJson;
}
