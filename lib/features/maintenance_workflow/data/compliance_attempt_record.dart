import 'package:isar/isar.dart';

part 'compliance_attempt_record.g.dart';

@collection
class ComplianceAttemptRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String firestoreId;

  @Index()
  late String complianceRequestFirestoreId;

  int attemptNumber = 1;
  late String attemptedByUid;
  String? attemptedByName;
  DateTime attemptedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String note = '';
  bool accepted = false;
  String? acceptedByUid;
  String? acceptedByName;
  DateTime? acceptedAt;
  String? returnedByUid;
  String? returnedByName;
  DateTime? returnedAt;
  String? returnReason;
  bool isSynced = true;
}
