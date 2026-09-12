import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../data/burner_condition_round.dart';
import 'burner_condition_round_service.dart';

typedef BurnerSubmissionInvoker =
    Future<Object?> Function(Map<String, dynamic> envelope);

/// Native custody is established before dispatch. Content hashes validate
/// evidence; a fresh operator action receives its own submission identity.
class BurnerConditionSubmissionController
    implements BurnerConditionSubmissionCommands {
  BurnerConditionSubmissionController({
    required this.store,
    required this.requireActor,
    required this.requireCapability,
    required this.invoke,
    required this.readLegacy,
    String Function()? newRequestId,
  }) : newRequestId = newRequestId ?? const Uuid().v4;

  final DurableSubmissionRepository store;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;
  final BurnerSubmissionInvoker invoke;
  final Future<Map<String, Uint8List>> Function(String actorUid) readLegacy;
  final String Function() newRequestId;

  AppUser _actor([String? origin]) {
    final actor = requireActor();
    if (!actor.isApproved ||
        !actor.canRecordBurnerConditionRound ||
        (origin != null && actor.uid != origin)) {
      throw const BurnerConditionRoundException(
        'Return to the approved account that saved these Burner/UV entries.',
        code: 'permission-denied',
      );
    }
    return actor;
  }

  static String resourceKey(String furnaceId) => 'burnerEvidence:$furnaceId';

  @override
  Future<List<DurableSubmission>> pending() async {
    final actor = _actor();
    final raw = await readLegacy(actor.uid);
    _actor(actor.uid);
    final legacy = <DurableSubmission>[];
    for (final entry in raw.entries) {
      // The old slot proves only a request/hash, not a full command or origin.
      // Preserve its exact bytes and source key without making it dispatchable.
      legacy.add(
        await store.importLegacyNeedsReview(
          submissionId: 'legacy-burner-${durableSubmissionSha256(entry.key)}',
          resourceKey: 'legacyBurner:${durableSubmissionSha256(entry.key)}',
          sourceKey: entry.key,
          sourceBytes: entry.value,
        ),
      );
      _actor(actor.uid);
    }
    final rows = await store.listForActor(actor.uid);
    _actor(actor.uid);
    return [
      ...legacy,
      ...rows.where((row) => row.resourceKey.startsWith('burnerEvidence:')),
    ];
  }

  @override
  Map<String, dynamic> requestOf(DurableSubmission row) {
    if (row.isLegacy || row.protocol != 'assetHierarchy.v2') {
      throw const BurnerConditionRoundException(
        'These old retry details need support review. Their full entries were not saved by the old app.',
        code: 'legacy-needs-review',
      );
    }
    final envelope = row.envelope;
    final raw = envelope['request'];
    if (envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != row.actorUid ||
        raw is! Map<String, dynamic> ||
        raw['requestId'] != row.requestId ||
        raw['assetInstanceId'] != row.aggregateId ||
        resourceKey(row.aggregateId) != row.resourceKey ||
        raw['assetClassId'] is! String ||
        (raw['assetClassId'] as String).trim().isEmpty ||
        !const [
          burnerConditionRoundOperation,
          burnerDirectiveComplianceOperation,
        ].contains(raw['operation'])) {
      throw const BurnerConditionRoundException(
        'Saved Burner/UV identities do not agree. The evidence is retained for review.',
        code: 'data-loss',
      );
    }
    return raw;
  }

  @override
  Future<Map<String, dynamic>> submit({
    required Map<String, dynamic> requestWithoutId,
    required String actorUid,
    required String furnaceName,
    Map<String, Object?> displayMetadata = const {},
  }) async {
    final actor = _actor(actorUid);
    final prior = await pending();
    _actor(actor.uid);
    if (prior.any((row) => row.isLegacy)) {
      throw const BurnerConditionRoundException(
        'Older Burner/UV retry evidence needs review before recording another round. It has been preserved.',
        code: 'legacy-needs-review',
      );
    }
    final furnaceId = requestWithoutId['assetInstanceId'] as String;
    final id = newRequestId();
    final row = await store.prepare(
      DurableSubmissionDraft(
        submissionId: id,
        actorUid: actor.uid,
        requestId: id,
        aggregateId: furnaceId,
        resourceKey: resourceKey(furnaceId),
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor.uid,
          'request': {'requestId': id, ...requestWithoutId},
        }),
        displayMetadataJson: jsonEncode({
          'furnaceName': furnaceName,
          ...displayMetadata,
        }),
      ),
    );
    _actor(actor.uid);
    return check(row.submissionId);
  }

  void _validate(DurableSubmission row, Map<String, dynamic> receipt) {
    final request = requestOf(row);
    if (request['operation'] == burnerConditionRoundOperation) {
      BurnerConditionRoundResult.fromCallableData(
        receipt,
        expectedRequestId: row.requestId,
        expectedAssetClassId: request['assetClassId'] as String,
        expectedAssetInstanceId: row.aggregateId,
      );
    } else {
      final result = BurnerDirectiveComplianceResult.fromCallableData(
        receipt,
        expectedRequestId: row.requestId,
        expectedAssetClassId: request['assetClassId'] as String,
        expectedAssetInstanceId: row.aggregateId,
        expectedDirectiveId: request['directiveId'] as String,
      );
      if (result.closedDirectiveVersion !=
          (request['expectedDirectiveVersion'] as int) + 1) {
        throw const BurnerConditionRoundException(
          'The closed directive version does not match the saved request.',
          code: 'data-loss',
        );
      }
    }
  }

  @override
  Future<Map<String, dynamic>> check(String submissionId) async {
    final row = await store.read(submissionId);
    if (row == null) {
      throw const BurnerConditionRoundException(
        'The saved Burner/UV request is missing.',
        code: 'data-loss',
      );
    }
    requestOf(row);
    _actor(row.actorUid);
    if (row.state.isAccepted) return _accepted(row);
    await requireCapability(row.actorUid!);
    _actor(row.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: row.actorUid!,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _accepted(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const BurnerConditionRoundException(
        'This saved request is already being checked or needs review. Keep its original entries and try again shortly.',
        code: 'saved-request-held',
      );
    }
    Map<String, dynamic> receipt;
    try {
      _actor(row.actorUid);
      final raw = await invoke(row.envelope);
      if (raw is! Map) {
        throw const FormatException('Invalid Burner/UV response.');
      }
      receipt = Map<String, dynamic>.from(raw);
      _validate(row, receipt);
    } catch (error) {
      final outcome = await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            'Outcome not confirmed. Check this saved request with its original entries.',
        errorCode: 'burner-outcome-uncertain',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(row.submissionId);
        if (accepted != null) return _accepted(accepted);
      }
      throw const BurnerConditionRoundException(
        'The outcome is not confirmed. Your complete Burner/UV entries are saved on this device; reopen and check them.',
        code: 'outcome-uncertain',
      );
    }
    // Replay flags are transport observations of one immutable acceptance.
    receipt['idempotentReplay'] = false;
    final accepted = await store.settleAccepted(
      submissionId: row.submissionId,
      envelopeSha256: row.envelopeSha256,
      receiptJson: jsonEncode(receipt),
      validateReceipt: (saved, response) {
        _validate(saved, response);
        return true;
      },
    );
    return _accepted(accepted);
  }

  Future<Map<String, dynamic>> _accepted(DurableSubmission row) async {
    final request = requestOf(row);
    _actor(row.actorUid);
    if (!row.state.isAccepted ||
        row.receiptJson == null ||
        row.receiptSha256 == null) {
      throw const BurnerConditionRoundException(
        'Saved acceptance needs review.',
        code: 'data-loss',
      );
    }
    final receipt = durableSubmissionJsonObject(row.receiptJson!);
    _validate(row, receipt);
    if (request['operation'] == burnerConditionRoundOperation) {
      await store.markReconciled(
        submissionId: row.submissionId,
        envelopeSha256: row.envelopeSha256,
        receiptSha256: row.receiptSha256!,
      );
      _actor(row.actorUid);
    }
    return receipt;
  }

  @override
  Future<void> finalizeDirective(String requestId, String actorUid) async {
    _actor(actorUid);
    final row = await store.read(requestId);
    _actor(actorUid);
    if (row == null ||
        row.actorUid != actorUid ||
        !row.state.isAccepted ||
        requestOf(row)['operation'] != burnerDirectiveComplianceOperation ||
        row.receiptSha256 == null) {
      throw const BurnerConditionRoundException(
        'Saved directive acceptance needs review.',
        code: 'data-loss',
      );
    }
    _validate(row, durableSubmissionJsonObject(row.receiptJson!));
    await store.markReconciled(
      submissionId: requestId,
      envelopeSha256: row.envelopeSha256,
      receiptSha256: row.receiptSha256!,
    );
    _actor(actorUid);
  }
}
