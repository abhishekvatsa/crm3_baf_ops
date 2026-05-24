import 'package:isar/isar.dart';

part 'charge_model.g.dart';

enum ChargeStatus { loaded, heat, cool, done, complete, deleted }
enum BuildMode { manual, auto }

@Collection()
class Charge {
  Id id = Isar.autoIncrement;

  // Cloud sync link — prevents duplicate Firestore documents on sync
  @Index(unique: true, replace: true)
  String? firestoreId;

  @Index(unique: true)
  late int chargeNo;  // Change to String if Level 2 ever produces suffixes like 145002-R
  int? heatNo;

  @Enumerated(EnumType.name)
  late ChargeStatus status;

  // Human readable only — asset IDs removed (NoSQL anti-pattern)
  int? baseNo;
  int? furnaceNo;
  int? forceCoolerNo;
  int? innerCoverNo;

  String? cycleType;

  @Enumerated(EnumType.name)
  BuildMode buildMode = BuildMode.manual;

  int? numberOfCoils;
  int? coilsInBase;

  // The 9 physical timestamps
  DateTime? builtDate;
  DateTime? loadedDate;
  DateTime? purgeDate;
  DateTime? standbyDate;
  DateTime? fireDate;      // ← intranet scraper writes here
  DateTime? offDate;       // ← intranet scraper writes here
  DateTime? coolDate;
  DateTime? coldDate;
  DateTime? unloadedDate;

  int? predHeatTime;
  int? revHeatTime;
  int? predCoolTime;
  int? revCoolTime;

  String rawTelemetry = '{}';

  bool hasAbnormal = false;
  String? updatedBy;
  DateTime? updatedDate;

  late DateTime createdAt;
  late DateTime updatedAt;

  bool isSynced = false;
}