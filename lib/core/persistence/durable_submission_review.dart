import 'dart:convert';

import 'durable_submission.dart';

/// Identifies evidence to review. It never reconstructs a dispatchable request
/// or assigns the current account as an unknown legacy command's origin.
class DurableSubmissionReviewTarget {
  const DurableSubmissionReviewTarget(this.domain, this.requestId);
  final String domain;
  final String requestId;

  String get callableName => switch (domain) {
    'inspectionCampaign' => 'executeMaintenanceWorkflowCommandV2',
    'qualityMonitoring' => 'mutateChargeAbnormalityV2',
    'publishedTemplateAssignment' => 'assignPublishedTemplateVersionV2',
    _ => 'mutateAssetHierarchyV2',
  };

  static DurableSubmissionReviewTarget from(DurableSubmission row) {
    final domain = switch (row.resourceKey.split(':').first) {
      'morningReview' => 'morningReview',
      'burnerEvidence' || 'legacyBurner' => 'burnerEvidence',
      'innerCoverAcceptance' => 'innerCoverAcceptance',
      'qualityMonitoringCreation' => 'qualityMonitoring',
      'publishedTemplateAssignment' => 'publishedTemplateAssignment',
      'inspectionCampaignCreation' => 'inspectionCampaign',
      _ => throw const DurableSubmissionException(
        'unsupported-review',
        'This kind of saved work requires specialist review. Its evidence is retained.',
      ),
    };
    var id = row.requestId;
    if (row.isLegacy) {
      final raw = row.legacySourceBase64;
      if (raw == null) _invalid();
      final decoded = durableSubmissionJsonObject(
        utf8.decode(base64Decode(raw)),
      );
      Map<String, dynamic> record = decoded;
      if (decoded.containsKey('journalVersion')) {
        if (decoded.length != 3 ||
            decoded['journalVersion'] != 1 ||
            decoded['savedAtMicros'] is! int ||
            decoded['record'] is! Map<String, dynamic>) {
          _invalid();
        }
        record = decoded['record'] as Map<String, dynamic>;
      }
      if (record['requestId'] is! String) _invalid();
      id = record['requestId'] as String;
    }
    if (id.isEmpty ||
        id == 'unknown' ||
        id.length > 256 ||
        id.trim() != id ||
        RegExp(r'[/\x00-\x1f\x7f]').hasMatch(id)) {
      _invalid();
    }
    return DurableSubmissionReviewTarget(domain, id);
  }
}

Never _invalid() => throw const DurableSubmissionException(
  'invalid-review-evidence',
  'The saved evidence cannot identify one original request safely. It remains retained for specialist review.',
);

void validateDurableSubmissionReviewDecision(
  DurableSubmission row,
  Map<String, dynamic> decision, {
  String? reviewerUid,
}) {
  final target = DurableSubmissionReviewTarget.from(row);
  const keys = {
    'schemaVersion',
    'domain',
    'requestId',
    'evidenceSha256',
    'originalActorUid',
    'reviewerUid',
    'outcome',
    'decisionId',
    'decidedAt',
    'receiptSha256',
    'receiptSummary',
    'reason',
  };
  final timestamp = decision['decidedAt'];
  final decidedAt = timestamp is String ? DateTime.tryParse(timestamp) : null;
  final hash = decision['receiptSha256'];
  final outcome = decision['outcome'];
  if (decision.length != keys.length ||
      !decision.keys.toSet().containsAll(keys) ||
      decision['schemaVersion'] != 1 ||
      decision['domain'] != target.domain ||
      decision['requestId'] != target.requestId ||
      decision['evidenceSha256'] != row.reviewEvidenceSha256 ||
      decision['originalActorUid'] != row.actorUid ||
      decision['reviewerUid'] is! String ||
      (decision['reviewerUid'] as String).trim().isEmpty ||
      (reviewerUid != null && decision['reviewerUid'] != reviewerUid) ||
      decision['decisionId'] is! String ||
      (decision['decisionId'] as String).trim().isEmpty ||
      decision['reason'] is! String ||
      (decision['reason'] as String).trim().isEmpty ||
      (decision['reason'] as String).length > 1600 ||
      timestamp is! String ||
      !timestamp.endsWith('Z') ||
      decidedAt == null ||
      decidedAt.toUtc().toIso8601String() != timestamp ||
      !const {'reviewedExisting', 'cancelled'}.contains(outcome) ||
      (outcome == 'cancelled' &&
          (hash != null || decision['receiptSummary'] != null)) ||
      (outcome == 'reviewedExisting' &&
          (hash is! String ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
              decision['receiptSummary'] is! Map))) {
    throw const DurableSubmissionException(
      'invalid-review-decision',
      'The review result does not match this exact saved evidence. The hold remains.',
    );
  }
}

void validateDurableSubmissionReviewHistory(
  DurableSubmission row,
  Map<String, dynamic> proof,
) {
  if (proof.length != 4 ||
      proof['schemaVersion'] != 1 ||
      proof['kind'] != 'savedSubmissionReview' ||
      proof['decisions'] is! List ||
      (proof['decisions'] as List).isEmpty ||
      proof['lateAcceptances'] is! List) {
    throw const DurableSubmissionException(
      'invalid-review-history',
      'Saved review history needs specialist attention.',
    );
  }
  for (final decision in proof['decisions'] as List) {
    if (decision is! Map<String, dynamic>) _invalid();
    validateDurableSubmissionReviewDecision(row, decision);
  }
  if ((proof['lateAcceptances'] as List).any(
    (receipt) => receipt is! Map<String, dynamic>,
  )) {
    _invalid();
  }
}
