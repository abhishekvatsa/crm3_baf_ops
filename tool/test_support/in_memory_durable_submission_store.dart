import 'dart:convert';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:isar_community/isar.dart';

/// UI test double only: no disk durability, corruption or native transaction
/// evidence. Use durable_submission_repository_test.dart for those guarantees.
/// Each transition replaces an immutable view; widget-held snapshots stay frozen.
class InMemoryDurableSubmissionStore implements DurableSubmissionRepository {
  InMemoryDurableSubmissionStore({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, DurableSubmission> _values = {};
  final Map<String, String> _immutable = {};
  int _token = 0;
  DateTime get _time => _now().toUtc();

  @override
  Isar get isar => throw UnsupportedError('UI test store has no native Isar.');

  @override
  Future<DurableSubmission> prepare(DurableSubmissionDraft draft) async {
    final frozen = jsonEncode(draft.toImmutableMap());
    final existing = _values[draft.submissionId];
    if (existing != null) {
      if (_immutable[draft.submissionId] != frozen) {
        _fail('identity-conflict', 'Saved submission evidence differs.');
      }
      return existing;
    }
    final envelope = durableSubmissionJsonObject(draft.envelopeJson);
    final innerKey = draft.protocol == 'maintenanceWorkflow.v2'
        ? 'command'
        : 'request';
    if (!DurableSubmissionRepository.supportedProtocols.contains(
          draft.protocol,
        ) ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != draft.actorUid ||
        envelope[innerKey] is! Map<String, dynamic>) {
      _fail(
        'invalid-protocol',
        'The frozen request needs its original account.',
      );
    }
    final inner = envelope[innerKey] as Map<String, dynamic>;
    final aggregateKey = DurableSubmissionRepository.aggregateIdentityKey(
      draft.protocol,
      inner,
    );
    if (inner[innerKey == 'request' ? 'requestId' : 'commandId'] !=
            draft.requestId ||
        inner[aggregateKey] != draft.aggregateId ||
        !DurableSubmissionRepository.validExpectedVersion(
          draft.protocol,
          inner,
        )) {
      _fail('invalid-protocol', 'Frozen request identities differ.');
    }
    if (_values.values.any(
      (value) =>
          value.protocol == draft.protocol &&
          value.requestId == draft.requestId,
    )) {
      _fail('identity-conflict', 'This request belongs to another submission.');
    }
    final owners = _owners(draft.resourceKey);
    if (owners.isNotEmpty) {
      throw DurableSubmissionException(
        'resource-pending',
        'An earlier submission for this item still needs confirmation.',
        submissionId: owners.first.submissionId,
      );
    }
    final at = _time;
    final value = DurableSubmission(
      submissionId: draft.submissionId,
      actorUid: draft.actorUid,
      requestId: draft.requestId,
      aggregateId: draft.aggregateId,
      resourceKey: draft.resourceKey,
      protocol: draft.protocol,
      envelopeJson: draft.envelopeJson,
      displayMetadataJson: draft.displayMetadataJson,
      state: DurableSubmissionState.intent,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      claimToken: null,
      claimExpiresAt: null,
      nextRetryAt: null,
      receiptJson: null,
      receiptSha256: null,
      lastErrorCode: null,
      lastErrorMessage: null,
      legacySourceKey: null,
      legacySourceBase64: null,
    );
    _immutable[draft.submissionId] = frozen;
    return _save(value);
  }

  @override
  Future<DurableSubmission?> read(String submissionId) async =>
      _values[submissionId];

  List<DurableSubmission> _owners(String resourceKey) => _values.values
      .where(
        (value) => value.resourceKey == resourceKey && value.state.isUnresolved,
      )
      .toList();

  @override
  Future<DurableSubmission?> findUnresolvedForResource(
    String resourceKey,
  ) async {
    final owners = _owners(resourceKey);
    if (owners.length > 1) {
      _fail('resource-conflict', 'Saved submission ownership needs review.');
    }
    return owners.isEmpty ? null : owners.single;
  }

  @override
  Future<DurableSubmission?> findUnresolved({
    required String actorUid,
    required String resourceKey,
  }) async {
    final value = await findUnresolvedForResource(resourceKey);
    return value?.actorUid == actorUid ? value : null;
  }

  @override
  Future<List<DurableSubmission>> listForActor(
    String actorUid, {
    bool includeTerminal = false,
  }) async =>
      _values.values
          .where(
            (value) =>
                value.actorUid == actorUid &&
                (includeTerminal || value.state.isUnresolved),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<DurableSubmissionClaim> claim({
    required String submissionId,
    required String actorUid,
    Duration lease = const Duration(minutes: 5),
  }) async {
    if (lease <= Duration.zero || lease > const Duration(hours: 1)) {
      throw ArgumentError.value(lease, 'lease');
    }
    final value = _required(submissionId);
    DurableSubmissionClaim stop(
      DurableSubmissionClaimDisposition disposition,
    ) => DurableSubmissionClaim(disposition: disposition, submission: value);
    if (actorUid.trim().isEmpty || value.actorUid != actorUid) {
      return stop(DurableSubmissionClaimDisposition.actorMismatch);
    }
    if (value.state.isAccepted) {
      return stop(DurableSubmissionClaimDisposition.accepted);
    }
    if (value.state == DurableSubmissionState.needsReview || value.isLegacy) {
      return stop(DurableSubmissionClaimDisposition.needsReview);
    }
    if (!value.state.isUnresolved) {
      return stop(DurableSubmissionClaimDisposition.terminal);
    }
    _soleOwner(value);
    final at = _time;
    if (value.claimExpiresAt?.isAfter(at) == true) {
      return stop(DurableSubmissionClaimDisposition.claimedElsewhere);
    }
    if (value.nextRetryAt?.isAfter(at) == true) {
      return stop(DurableSubmissionClaimDisposition.notDue);
    }
    final token = 'ui-test-claim-${++_token}';
    final claimed = _save(
      _replace(
        value,
        state: DurableSubmissionState.sending,
        attemptCount: value.attemptCount + 1,
        claimToken: token,
        claimExpiresAt: at.add(lease),
      ),
    );
    return DurableSubmissionClaim(
      disposition: DurableSubmissionClaimDisposition.claimed,
      submission: claimed,
      token: token,
    );
  }

  @override
  Future<DurableSubmissionOutcome> recordOutcome(
    DurableSubmissionClaim claim, {
    required DurableSubmissionState state,
    required String message,
    String? errorCode,
    DateTime? nextRetryAt,
  }) async {
    if (!claim.mayDispatch ||
        claim.token == null ||
        !const {
          DurableSubmissionState.uncertain,
          DurableSubmissionState.rejected,
          DurableSubmissionState.needsReview,
        }.contains(state)) {
      throw ArgumentError('Only dispatch claims can record attempt outcomes.');
    }
    final value = _required(claim.submission.submissionId);
    _sameEnvelope(value, claim.submission.envelopeSha256);
    if (value.state.isAccepted) return DurableSubmissionOutcome.alreadyAccepted;
    if (value.claimToken != claim.token ||
        value.state != DurableSubmissionState.sending ||
        value.claimExpiresAt?.isAfter(_time) != true) {
      return DurableSubmissionOutcome.staleClaim;
    }
    _save(
      _replace(
        value,
        state: state,
        lastErrorCode: errorCode,
        lastErrorMessage: message,
        nextRetryAt: state == DurableSubmissionState.uncertain
            ? nextRetryAt
            : null,
      ),
    );
    return DurableSubmissionOutcome.recorded;
  }

  @override
  Future<DurableSubmission> settleAccepted({
    required String submissionId,
    required String envelopeSha256,
    required String receiptJson,
    required DurableReceiptValidator validateReceipt,
  }) async {
    final value = _required(submissionId);
    _sameEnvelope(value, envelopeSha256);
    final receipt = durableSubmissionJsonObject(receiptJson);
    if (value.isLegacy ||
        value.attemptCount == 0 ||
        !validateReceipt(value, receipt)) {
      _fail(
        'invalid-receipt',
        'The receipt does not validate this submission.',
      );
    }
    if (value.state.isAccepted) {
      if (value.receiptJson != receiptJson) {
        _fail(
          'acceptance-conflict',
          'A different acceptance is already retained.',
        );
      }
      return value;
    }
    final neighbours = _owners(
      value.resourceKey,
    ).where((other) => other.submissionId != submissionId).toList();
    for (final other in neighbours) {
      _save(
        _replace(
          other,
          state: other.state.isAccepted
              ? other.state
              : DurableSubmissionState.needsReview,
          lastErrorCode: 'resource-conflict',
          lastErrorMessage: 'Another submission for this item needs review.',
        ),
      );
    }
    return _save(
      _replace(
        value,
        state: DurableSubmissionState.acceptedPendingAdoption,
        receiptJson: receiptJson,
        receiptSha256: durableSubmissionSha256(receiptJson),
        lastErrorCode: neighbours.isEmpty ? null : 'resource-conflict',
        lastErrorMessage: neighbours.isEmpty
            ? null
            : 'Another submission for this item needs review.',
      ),
    );
  }

  @override
  Future<DurableSubmission> markReconciled({
    required String submissionId,
    required String envelopeSha256,
    required String receiptSha256,
    Future<void> Function(Isar transactionStore)? adoptInTransaction,
  }) async {
    if (adoptInTransaction != null) {
      throw UnsupportedError(
        'Native adoption transactions require the real Isar fixture.',
      );
    }
    final value = _required(submissionId);
    _sameEnvelope(value, envelopeSha256);
    if (!value.state.isAccepted || value.receiptSha256 != receiptSha256) {
      _fail('unconfirmed-acceptance', 'Confirm the retained acceptance first.');
    }
    if (value.state == DurableSubmissionState.reconciled) return value;
    _soleOwner(value);
    return _save(_replace(value, state: DurableSubmissionState.reconciled));
  }

  @override
  Future<DurableSubmission> cancelNeverSent({
    required String submissionId,
    required String actorUid,
  }) async {
    final value = _required(submissionId);
    if (value.actorUid != actorUid ||
        value.state != DurableSubmissionState.intent ||
        value.attemptCount != 0) {
      _fail(
        'cancellation-unproven',
        'This submission may have been sent. Confirm it first.',
      );
    }
    return _save(
      _replace(value, state: DurableSubmissionState.cancelledBeforeSend),
    );
  }

  @override
  Future<DurableSubmission> importLegacyNeedsReview({
    required String submissionId,
    required String resourceKey,
    required String sourceKey,
    required Uint8List sourceBytes,
    String? actorUid,
    String requestId = 'unknown',
    String aggregateId = 'unknown',
  }) => throw UnsupportedError(
    'Legacy byte preservation requires the real Isar fixture.',
  );

  DurableSubmission _required(String id) =>
      _values[id] ??
      (throw const DurableSubmissionException(
        'missing-submission',
        'Saved submission could not be found.',
      ));

  void _sameEnvelope(DurableSubmission value, String hash) {
    if (value.envelopeSha256 != hash) {
      _fail(
        'identity-conflict',
        'This outcome belongs to different frozen evidence.',
      );
    }
  }

  void _soleOwner(DurableSubmission value) {
    final owners = _owners(value.resourceKey);
    if (owners.length != 1 ||
        owners.single.submissionId != value.submissionId) {
      _fail('resource-conflict', 'Saved submission ownership needs review.');
    }
  }

  DurableSubmission _save(DurableSubmission value) =>
      _values[value.submissionId] = value;

  DurableSubmission _replace(
    DurableSubmission value, {
    required DurableSubmissionState state,
    int? attemptCount,
    String? claimToken,
    DateTime? claimExpiresAt,
    DateTime? nextRetryAt,
    String? receiptJson,
    String? receiptSha256,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) => DurableSubmission(
    submissionId: value.submissionId,
    actorUid: value.actorUid,
    requestId: value.requestId,
    aggregateId: value.aggregateId,
    resourceKey: value.resourceKey,
    protocol: value.protocol,
    envelopeJson: value.envelopeJson,
    displayMetadataJson: value.displayMetadataJson,
    state: state,
    attemptCount: attemptCount ?? value.attemptCount,
    createdAt: value.createdAt,
    updatedAt: _time,
    claimToken: claimToken,
    claimExpiresAt: claimExpiresAt,
    nextRetryAt: nextRetryAt?.toUtc(),
    receiptJson: receiptJson ?? value.receiptJson,
    receiptSha256: receiptSha256 ?? value.receiptSha256,
    lastErrorCode: lastErrorCode,
    lastErrorMessage: lastErrorMessage,
    legacySourceKey: value.legacySourceKey,
    legacySourceBase64: value.legacySourceBase64,
  );

  Never _fail(String code, String message) =>
      throw DurableSubmissionException(code, message);
}
