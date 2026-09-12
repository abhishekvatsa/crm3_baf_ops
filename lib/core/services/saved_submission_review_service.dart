import 'dart:convert';

import '../../features/auth/data/user_model.dart';
import '../persistence/durable_submission_repository.dart';
import '../persistence/durable_submission_review.dart';

class SavedSubmissionReviewInspection {
  SavedSubmissionReviewInspection({
    required this.row,
    required this.reason,
    required this.reviewerUid,
    required Map<String, dynamic> response,
    this.alreadyResolved = false,
  }) : response = Map.unmodifiable(response);
  final DurableSubmission row;
  final String reason;
  final String reviewerUid;
  final Map<String, dynamic> response;
  final bool alreadyResolved;
}

class SavedSubmissionReviewService {
  SavedSubmissionReviewService({
    required this.store,
    required this.requireReviewer,
    required this.requireCapability,
    required this.invoke,
  });
  final DurableSubmissionRepository store;
  final AppUser Function() requireReviewer;
  final Future<void> Function(String callable, String uid) requireCapability;
  final Future<Object?> Function(String callable, Map<String, dynamic> data)
  invoke;

  AppUser _admin([String? expectedUid]) {
    final actor = requireReviewer();
    if (!actor.isApproved ||
        !actor.isAdmin ||
        (expectedUid != null && actor.uid != expectedUid)) {
      throw const DurableSubmissionException(
        'review-admin-required',
        'A currently approved administrator must review saved work.',
      );
    }
    return actor;
  }

  Future<List<DurableSubmission>> list() async {
    final uid = _admin().uid;
    final result = await store.listForAdministrativeReview(
      requireReviewer: () => _admin(uid),
    );
    _admin(uid);
    return result;
  }

  Map<String, dynamic> _request(
    DurableSubmission row,
    String phase,
    String reason, {
    String? token,
  }) {
    final target = DurableSubmissionReviewTarget.from(row);
    return {
      'schemaVersion': 1,
      'phase': phase,
      'domain': target.domain,
      'requestId': target.requestId,
      'evidenceSha256': row.reviewEvidenceSha256,
      'originalActorUid': row.actorUid,
      'reason': reason,
      if (token != null) 'reviewToken': token,
    };
  }

  Future<SavedSubmissionReviewInspection> inspect(
    DurableSubmission row,
    String reason,
  ) async {
    final uid = _admin().uid;
    final cleaned = reason.trim();
    if (cleaned.length < 10 || cleaned.length > 1600) {
      throw const DurableSubmissionException(
        'review-reason-required',
        'Describe what you checked and why this request can be reviewed (10–1600 characters).',
      );
    }
    if (row.state.isAccepted ||
        !row.state.isUnresolved ||
        row.state == DurableSubmissionState.reviewConflict) {
      throw const DurableSubmissionException(
        'review-state',
        'Use the original business page to check an accepted result. A conflicting review needs specialist investigation.',
      );
    }
    final target = DurableSubmissionReviewTarget.from(row);
    await requireCapability(target.callableName, uid);
    _admin(uid);
    final raw = await invoke(target.callableName, {
      'protocolVersion': 2,
      'originActorUid': uid,
      'recovery': _request(row, 'inspect', cleaned),
    });
    _admin(uid);
    final response = durableSubmissionJsonObject(jsonEncode(raw));
    if (response.containsKey('outcome')) {
      // A previous finalization may have committed while its reply was lost.
      // Adopt its immutable decision and original reason; never issue another
      // cancellation or demand that the reviewer remembers an unsaved note.
      validateDurableSubmissionReviewDecision(row, response, reviewerUid: uid);
      await store.settleReview(
        submissionId: row.submissionId,
        evidenceSha256: row.reviewEvidenceSha256,
        reviewerUid: uid,
        decisionJson: jsonEncode(response),
        requireReviewer: () => _admin(uid),
      );
      _admin(uid);
      return SavedSubmissionReviewInspection(
        row: row,
        reason: response['reason'] as String,
        reviewerUid: uid,
        response: response,
        alreadyResolved: true,
      );
    }
    const keys = {
      'schemaVersion',
      'domain',
      'requestId',
      'evidenceSha256',
      'originalActorUid',
      'reviewerUid',
      'reviewToken',
      'observation',
      'receiptSha256',
      'receiptSummary',
    };
    final present = response['observation'] == 'receiptPresent';
    if (response.length != keys.length ||
        !response.keys.toSet().containsAll(keys) ||
        response['schemaVersion'] != 1 ||
        response['domain'] != target.domain ||
        response['requestId'] != target.requestId ||
        response['evidenceSha256'] != row.reviewEvidenceSha256 ||
        response['originalActorUid'] != row.actorUid ||
        response['reviewerUid'] != uid ||
        response['reviewToken'] is! String ||
        !RegExp(
          r'^[a-f0-9]{64}$',
        ).hasMatch(response['reviewToken'] as String) ||
        !const {
          'receiptPresent',
          'receiptAbsent',
        }.contains(response['observation']) ||
        (present &&
            (response['receiptSha256'] is! String ||
                !RegExp(
                  r'^[a-f0-9]{64}$',
                ).hasMatch(response['receiptSha256'] as String) ||
                response['receiptSummary'] is! Map)) ||
        (!present &&
            (response['receiptSha256'] != null ||
                response['receiptSummary'] != null))) {
      throw const DurableSubmissionException(
        'invalid-review-inspection',
        'The server inspection does not match this saved evidence. The hold remains.',
      );
    }
    return SavedSubmissionReviewInspection(
      row: row,
      reason: cleaned,
      reviewerUid: uid,
      response: response,
    );
  }

  Future<DurableSubmission> finalize(
    SavedSubmissionReviewInspection inspection,
  ) async {
    final uid = inspection.reviewerUid;
    _admin(uid);
    final row = await store.read(inspection.row.submissionId);
    _admin(uid);
    if (row == null ||
        row.reviewEvidenceSha256 != inspection.row.reviewEvidenceSha256) {
      throw const DurableSubmissionException(
        'review-evidence-changed',
        'The saved evidence changed. Inspect it again.',
      );
    }
    if (inspection.alreadyResolved &&
        row.state == DurableSubmissionState.reviewResolved) {
      return row;
    }
    if (row.state.isAccepted ||
        row.state == DurableSubmissionState.reviewConflict ||
        (!row.state.isUnresolved &&
            row.state != DurableSubmissionState.reviewResolved)) {
      throw const DurableSubmissionException(
        'review-outcome-changed',
        'The saved outcome changed during review. Check its retained evidence again.',
      );
    }
    final target = DurableSubmissionReviewTarget.from(row);
    await requireCapability(target.callableName, uid);
    _admin(uid);
    final raw = await invoke(target.callableName, {
      'protocolVersion': 2,
      'originActorUid': uid,
      'recovery': _request(
        row,
        'finalize',
        inspection.reason,
        token: inspection.response['reviewToken'] as String,
      ),
    });
    _admin(uid);
    final decision = durableSubmissionJsonObject(jsonEncode(raw));
    validateDurableSubmissionReviewDecision(row, decision, reviewerUid: uid);
    if (decision['reason'] != inspection.reason ||
        decision['receiptSha256'] != inspection.response['receiptSha256'] ||
        (decision['outcome'] == 'reviewedExisting') !=
            (inspection.response['observation'] == 'receiptPresent')) {
      throw const DurableSubmissionException(
        'review-observation-changed',
        'The outcome changed during review. Inspect it again; original evidence is retained.',
      );
    }
    final result = await store.settleReview(
      submissionId: row.submissionId,
      evidenceSha256: row.reviewEvidenceSha256,
      reviewerUid: uid,
      decisionJson: jsonEncode(decision),
      requireReviewer: () => _admin(uid),
    );
    _admin(uid);
    return result;
  }
}
