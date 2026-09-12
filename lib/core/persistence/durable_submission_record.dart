import 'package:isar_community/isar.dart';

part 'durable_submission_record.g.dart';

/// Native submission evidence. Only DurableSubmissionRepository mutates rows.
/// Completed and rejected identities are retained, never replaced or deleted.
@collection
class DurableSubmissionRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String submissionId;

  @Index(unique: true)
  late String requestKey;

  @Index()
  late String resourceKey;

  @Index()
  String? actorUid;

  late String immutableJson;
  late String immutableSha256;
  String stateKey = 'intent';
  int attemptCount = 0;
  late DateTime createdAt;
  late DateTime updatedAt;
  String? claimToken;
  DateTime? claimExpiresAt;
  DateTime? nextRetryAt;
  String? receiptJson;
  String? receiptSha256;
  DateTime? acceptedAt;
  DateTime? reconciledAt;
  String? lastErrorCode;
  String? lastErrorMessage;
}
