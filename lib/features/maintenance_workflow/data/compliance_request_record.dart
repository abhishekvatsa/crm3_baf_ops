import 'package:isar/isar.dart';

part 'compliance_request_record.g.dart';

@collection
class ComplianceRequestRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? firestoreId;
  @Index()
  bool isSynced = false;
  int version = 1;

  late String title;
  late String description;
  String? originLaneKey;
  @Index()
  late String targetLaneKey;
  @Index()
  String statusKey = 'raised';
  @Index()
  String conditionTypeKey = 'manual';
  @Index()
  String? conditionRef;
  String priorityKey = 'medium';

  String? raisedByUid;
  String? raisedByName;
  DateTime? raisedAt;
  String? acknowledgedByUid;
  String? acknowledgedByName;
  DateTime? acknowledgedAt;
  String? compliedByUid;
  String? compliedByName;
  DateTime? compliedAt;
  String? complianceNote;
  String? currentAttemptId;
  int attemptCount = 0;
  String? confirmedByUid;
  String? confirmedByName;
  DateTime? confirmedAt;
  String? confirmNote;

  DateTime? becameDueAt;
  String? dueMarkedByUid;
  String? dueMarkedByName;
  DateTime? dueMarkedAt;

  int counterDepth = 0;
  @Index()
  String? counterConditionOfId;
  String? supersededById;
  String? counterProposedByUid;
  String? counterProposedByName;
  DateTime? counterProposedAt;
  String? counterRevisedDescription;
  String? counterDecisionByUid;
  String? counterDecisionByName;
  DateTime? counterDecisionAt;
  String? counterDecisionNote;

  int correctionCount = 0;
  String? lastCorrectionByUid;
  String? lastCorrectionByName;
  DateTime? lastCorrectionAt;
  String? lastCorrectionReason;

  @Index()
  String? linkedWorkflowId;
  @Index()
  String? linkedMaintenanceFirestoreId;
  @Index()
  String? linkedExecutionFirestoreId;
  String? linkedLaneFirestoreId;
  String? linkedModuleFirestoreId;
  @Index()
  String? gatesLaneFirestoreId;

  @Index()
  String assetTypeKey = 'base';
  @Index()
  int assetNumber = 0;
  int? chargeNoAtEvent;

  int escalationTier = 0;
  DateTime? lastEscalatedAt;
  DateTime? acknowledgementDueAt;
  DateTime? complianceDueAt;

  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool isDeleted = false;
  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;
  String? metadataJson;
}
