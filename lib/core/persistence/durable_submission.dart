import 'dart:convert';

import 'package:crypto/crypto.dart';

enum DurableSubmissionState {
  intent,
  sending,
  uncertain,
  acceptedPendingAdoption,
  reconciled,
  rejected,
  needsReview,
  cancelledBeforeSend,
  reviewResolved,
  reviewConflict,
}

extension DurableSubmissionStateMeaning on DurableSubmissionState {
  bool get isAccepted =>
      this == DurableSubmissionState.acceptedPendingAdoption ||
      this == DurableSubmissionState.reconciled;
  bool get isUnresolved =>
      this != DurableSubmissionState.reconciled &&
      this != DurableSubmissionState.rejected &&
      this != DurableSubmissionState.reviewResolved &&
      this != DurableSubmissionState.cancelledBeforeSend;
}

class DurableSubmissionException implements Exception {
  const DurableSubmissionException(
    this.code,
    this.message, {
    this.submissionId,
  });
  final String code;
  final String message;
  final String? submissionId;
  @override
  String toString() => message;
}

/// A logical operator submission, not a content fingerprint. Repeated identical
/// business actions have different submission IDs after prior work is resolved.
class DurableSubmissionDraft {
  const DurableSubmissionDraft({
    required this.submissionId,
    required this.actorUid,
    required this.requestId,
    required this.aggregateId,
    required this.resourceKey,
    required this.protocol,
    required this.envelopeJson,
    this.displayMetadataJson,
  });
  final String submissionId;
  final String actorUid;
  final String requestId;
  final String aggregateId;
  final String resourceKey;
  final String protocol;
  final String envelopeJson;
  final String? displayMetadataJson;

  Map<String, dynamic> toImmutableMap() => <String, dynamic>{
    'schemaVersion': 1,
    'submissionId': submissionId,
    'actorUid': actorUid,
    'requestId': requestId,
    'aggregateId': aggregateId,
    'resourceKey': resourceKey,
    'protocol': protocol,
    'envelopeJson': envelopeJson,
    'displayMetadataJson': displayMetadataJson,
    'legacySourceKey': null,
    'legacySourceBase64': null,
  };
}

/// Immutable view; controllers never receive the mutable Isar record.
class DurableSubmission {
  const DurableSubmission({
    required this.submissionId,
    required this.actorUid,
    required this.requestId,
    required this.aggregateId,
    required this.resourceKey,
    required this.protocol,
    required this.envelopeJson,
    required this.displayMetadataJson,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    required this.claimToken,
    required this.claimExpiresAt,
    required this.nextRetryAt,
    required this.receiptJson,
    required this.receiptSha256,
    required this.lastErrorCode,
    required this.lastErrorMessage,
    required this.legacySourceKey,
    required this.legacySourceBase64,
  });
  final String submissionId;
  final String? actorUid;
  final String requestId;
  final String aggregateId;
  final String resourceKey;
  final String protocol;
  final String envelopeJson;
  final String? displayMetadataJson;
  final DurableSubmissionState state;

  /// Dispatch grants, including a process ending before the network call.
  /// This is not a count of proven network transmissions.
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? claimToken;
  final DateTime? claimExpiresAt;
  final DateTime? nextRetryAt;
  final String? receiptJson;
  final String? receiptSha256;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final String? legacySourceKey;
  final String? legacySourceBase64;
  bool get isLegacy => legacySourceKey != null;
  String get envelopeSha256 => durableSubmissionSha256(envelopeJson);

  /// Binds review to all original evidence, including unknown legacy origin.
  String get reviewEvidenceSha256 => durableSubmissionSha256(
    jsonEncode({
      'schemaVersion': 1,
      'submissionId': submissionId,
      'actorUid': actorUid,
      'requestId': requestId,
      'aggregateId': aggregateId,
      'resourceKey': resourceKey,
      'protocol': protocol,
      'envelopeJson': envelopeJson,
      'displayMetadataJson': displayMetadataJson,
      'legacySourceKey': legacySourceKey,
      'legacySourceBase64': legacySourceBase64,
    }),
  );
  Map<String, dynamic> get envelope =>
      durableSubmissionJsonObject(envelopeJson);
}

enum DurableSubmissionClaimDisposition {
  claimed,
  accepted,
  terminal,
  needsReview,
  notDue,
  claimedElsewhere,
  actorMismatch,
}

class DurableSubmissionClaim {
  const DurableSubmissionClaim({
    required this.disposition,
    required this.submission,
    this.token,
  });
  final DurableSubmissionClaimDisposition disposition;
  final DurableSubmission submission;
  final String? token;
  bool get mayDispatch =>
      disposition == DurableSubmissionClaimDisposition.claimed;
}

enum DurableSubmissionOutcome { recorded, alreadyAccepted, staleClaim }

typedef DurableReceiptValidator =
    bool Function(DurableSubmission submission, Map<String, dynamic> receipt);

String durableSubmissionSha256(String value) =>
    sha256.convert(utf8.encode(value)).toString();

Map<String, dynamic> durableSubmissionJsonObject(String raw) {
  if (utf8.encode(raw).length > 524288) {
    throw const DurableSubmissionException(
      'invalid-data',
      'The saved submission exceeds the supported size. Nothing was sent.',
    );
  }
  final Object? value;
  try {
    value = jsonDecode(raw);
  } on FormatException {
    throw const DurableSubmissionException(
      'invalid-data',
      'Saved submission evidence is malformed and has been preserved.',
    );
  }
  if (value is! Map<String, dynamic>) {
    throw const DurableSubmissionException(
      'invalid-data',
      'Saved submission evidence must be an object and has been preserved.',
    );
  }
  return value;
}
