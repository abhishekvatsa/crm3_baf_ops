import 'dart:convert';

import 'durable_submission.dart';
import 'durable_submission_review.dart';

const reviewedAcceptanceKind = 'acceptedAfterSavedSubmissionReview';

/// This compares acceptance identity, not the server's private receipt digest:
/// that digest covers a richer stored document than the callable response.
/// The caller must first validate every receipt against the frozen domain input.
bool confirmsReviewedAcceptance(
  DurableSubmission row,
  Map<String, dynamic> history,
  Map<String, dynamic> receipt,
) {
  if (row.isLegacy || row.actorUid == null || row.attemptCount == 0) {
    return false;
  }
  validateDurableSubmissionReviewHistory(row, history);
  final expected = _acceptanceSummary(row, receipt);
  if (expected == null) return false;
  String? originalReceiptHash;
  for (final raw in history['decisions'] as List) {
    final decision = raw as Map<String, dynamic>;
    if (decision['outcome'] != 'reviewedExisting' ||
        !sameSubmissionJson(decision['receiptSummary'], expected)) {
      return false;
    }
    final hash = decision['receiptSha256'] as String;
    originalReceiptHash ??= hash;
    if (hash != originalReceiptHash) return false;
  }
  for (final prior in history['lateAcceptances'] as List) {
    if (!sameSubmissionJson(prior, receipt) ||
        !sameSubmissionJson(
          _acceptanceSummary(row, prior as Map<String, dynamic>),
          expected,
        )) {
      return false;
    }
  }
  return true;
}

bool sameSubmissionJson(Object? left, Object? right) =>
    jsonEncode(_ordered(left)) == jsonEncode(_ordered(right));

Object? _ordered(Object? value) {
  if (value is List) return value.map(_ordered).toList();
  if (value is Map<String, dynamic>) {
    return {
      for (final key in value.keys.toList()..sort()) key: _ordered(value[key]),
    };
  }
  return value;
}

Map<String, dynamic>? _acceptanceSummary(
  DurableSubmission row,
  Map<String, dynamic> receipt,
) {
  final outer = row.envelope;
  final domain = DurableSubmissionReviewTarget.from(row).domain;
  final inner = outer[domain == 'inspectionCampaign' ? 'command' : 'request'];
  if (outer['originActorUid'] != row.actorUid ||
      inner is! Map<String, dynamic>) {
    return null;
  }
  Object? operation;
  Object? entity;
  Object? version;
  Object? committedAt;
  Object? status;
  if (domain == 'inspectionCampaign') {
    if (row.protocol != 'maintenanceWorkflow.v2' ||
        inner['commandType'] != 'createInspectionCampaign' ||
        receipt['commandId'] != row.requestId ||
        receipt['resultKey'] != 'inspection-campaign-created') {
      return null;
    }
    final result = receipt['result'];
    if (result is! Map<String, dynamic> ||
        result['campaignId'] != row.aggregateId ||
        result['status'] != 'open') {
      return null;
    }
    operation = inner['commandType'];
    entity = result['campaignId'];
    version = receipt['aggregateVersion'];
    committedAt = receipt['appliedAt'];
  } else {
    if (receipt['requestId'] != row.requestId ||
        inner['requestId'] != row.requestId) {
      return null;
    }
    if (domain == 'publishedTemplateAssignment') {
      if (row.protocol != 'publishedTemplateAssignment.v2' ||
          receipt['ok'] != true) {
        return null;
      }
      operation = 'assignPublishedTemplateVersion';
      entity = receipt['executionId'];
      version = inner['expectedVersionNumber'];
      committedAt = receipt['assignedAt'];
      status = 'completed';
    } else {
      operation = receipt['operation'];
      if (operation != inner['operation']) return null;
      committedAt = receipt['committedAt'];
      switch (domain) {
        case 'innerCoverAcceptance':
          if (row.protocol != 'assetHierarchy.v2' ||
              operation != 'ACCEPT_INNER_COVER') {
            return null;
          }
          entity = receipt['innerCoverId'];
          version = receipt['version'];
        case 'qualityMonitoring':
          if (row.protocol != 'chargeAbnormality.v2' ||
              operation != 'CREATE_QUALITY_MONITORING_REQUEST') {
            return null;
          }
          entity = receipt['entityId'];
          version = receipt['version'];
        case 'burnerEvidence':
          if (row.protocol != 'assetHierarchy.v2') return null;
          entity = receipt['assetInstanceId'];
          if (operation == 'RECORD_BURNER_CONDITION_ROUND') {
            // A condition observation snapshots, rather than increments, the
            // expected registry version. That version is not in its response.
            version = inner['expectedAssetVersion'];
          } else if (operation == 'COMPLETE_BURNER_RED_HOT_DIRECTIVE') {
            version = receipt['closedDirectiveVersion'];
          } else {
            return null;
          }
        case 'morningReview':
          if (row.protocol != 'assetHierarchy.v2') return null;
          entity = receipt['entityId'];
          version = receipt['version'];
          status = receipt['status'];
        default:
          return null;
      }
    }
  }
  final at = committedAt is String ? DateTime.tryParse(committedAt) : null;
  if (operation is! String ||
      operation.isEmpty ||
      entity is! String ||
      entity.isEmpty ||
      version is! int ||
      version < 1 ||
      version > 9007199254740991 ||
      committedAt is! String ||
      at == null ||
      at.toUtc().toIso8601String() != committedAt ||
      (status != null && status is! String)) {
    return null;
  }
  // Assignment uses the request as its local aggregate; its server-generated
  // execution identity is bound by the domain receipt validator and review.
  // Morning Review likewise returns a derived session/action/entry identity.
  if (domain != 'morningReview' &&
      domain != 'publishedTemplateAssignment' &&
      entity != row.aggregateId) {
    return null;
  }
  return {
    'actorUid': row.actorUid,
    'operation': operation,
    'entityId': entity,
    'version': version,
    'committedAt': committedAt,
    'status': status,
  };
}

/// The persisted capsule keeps both immutable histories. Older v12 readers
/// retain it as accepted/unresolved; existing strict domain readers refuse its
/// unsupported response shape, rather than sending the original request again.
String reviewedAcceptanceCapsule({
  required Map<String, dynamic> history,
  required String acceptanceJson,
}) => jsonEncode({
  'schemaVersion': 1,
  'kind': reviewedAcceptanceKind,
  'reviewHistory': history,
  'acceptanceJson': acceptanceJson,
});

({String acceptanceJson, Map<String, dynamic> history})?
readReviewedAcceptanceCapsule(String raw) {
  final value = durableSubmissionJsonObject(raw);
  if (value['kind'] != reviewedAcceptanceKind) return null;
  if (value.length != 4 ||
      value['schemaVersion'] != 1 ||
      value['reviewHistory'] is! Map<String, dynamic> ||
      value['acceptanceJson'] is! String) {
    throw const DurableSubmissionException(
      'invalid-review-acceptance',
      'Saved acceptance and review history need investigation. Both are retained.',
    );
  }
  return (
    acceptanceJson: value['acceptanceJson'] as String,
    history: value['reviewHistory'] as Map<String, dynamic>,
  );
}
