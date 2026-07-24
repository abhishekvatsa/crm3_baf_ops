import 'package:isar/isar.dart';

part 'job_lane_record.g.dart';

@collection
class JobLaneRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? firestoreId;

  @Index()
  late String workflowFirestoreId;

  @Index()
  late String jobExecutionFirestoreId;

  @Index()
  int? jobExecutionLocalId;

  /// Raw key preserves unknown values for quarantine instead of coercing them.
  @Index()
  late String laneKey;

  @Index()
  String statusKey = 'pending';

  @Index()
  int activationGeneration = 1;

  int version = 1;
  int progressRevision = 0;

  @Index()
  bool isSynced = false;

  bool laneSetFinalized = false;
  bool addedDuringExecution = false;
  String? addedByUid;
  String? addedByName;
  DateTime? addedAt;
  String? addReason;

  String? acknowledgedByUid;
  String? acknowledgedByName;
  DateTime? acknowledgedAt;

  String? closedByUid;
  String? closedByName;
  DateTime? closedAt;
  String? closeNote;

  String? removedByUid;
  String? removedByName;
  DateTime? removedAt;
  String? removeReason;

  String? terminatedByUid;
  String? terminatedByName;
  DateTime? terminatedAt;
  String? terminateReason;

  String? representedLaneKey;
  String? delegationBasis;
  String? gatingComplianceRequestId;

  @Index()
  int assetNumber = 0;
  @Index()
  String assetTypeKey = 'base';
  int? chargeNoAtEvent;

  int displayOrder = 0;
  DateTime? acknowledgementDueAt;
  int escalationTier = 0;
  DateTime? lastEscalatedAt;

  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? createdByUid;
  String? createdByName;
  String? updatedByUid;
  String? updatedByName;

  bool isDeleted = false;
  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;
  String? metadataJson;
}
